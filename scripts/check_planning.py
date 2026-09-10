#!/usr/bin/env python3
"""Read-only mapping approval and bring-up gates; not numerical or RTL signoff.

Paths are relative to --root, normally the repository root. No model code is
imported or executed. See docs/model_graph_bringup.md for the supported format.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


class PlanningError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise PlanningError(message)


def text(value, where):
    require(isinstance(value, str) and value.strip(), f'nonempty text required: {where}')
    return value


def obj(value, where):
    require(isinstance(value, dict), f'object required: {where}')
    return value


def array(value, where):
    require(isinstance(value, list), f'list required: {where}')
    return value


def identifier(value, where):
    text(value, where)
    require(re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.:-]*', value),
            f'invalid ID (use / only in expanded node references): {where}')
    return value


def ids(value, where):
    values = array(value, where)
    for item in values:
        identifier(item, where)
    require(len(set(values)) == len(values), f'duplicate IDs: {where}')
    return set(values)


def file_path(root, value):
    text(value, 'path')
    rel = Path(value)
    require(not rel.is_absolute() and '..' not in rel.parts, f'unsafe path: {value}')
    require(rel.as_posix() == value, f'noncanonical path: {value}')
    p = root
    for part in rel.parts:
        p = p / part
        require(not p.is_symlink(), f'symlink forbidden: {value}')
    require(p.resolve().is_relative_to(root.resolve()), f'outside root: {value}')
    require(p.is_file(), f'missing file: {value}')
    return p


def digest(root, value):
    return hashlib.sha256(file_path(root, value).read_bytes()).hexdigest()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f'duplicate JSON key: {key}')
        result[key] = value
    return result


def reject_constant(value):
    raise PlanningError(f'non-JSON numeric constant: {value}')


def read(root, value):
    try:
        document = json.loads(file_path(root, value).read_text(encoding='utf-8'),
                              object_pairs_hook=unique_object,
                              parse_constant=reject_constant)
    except (UnicodeError, json.JSONDecodeError) as error:
        raise PlanningError(f'invalid JSON: {value}: {error}') from error
    return obj(document, value)


def reference(root, value, where, inventory):
    ref = obj(value, where)
    require(set(ref) == {'path', 'sha256'}, f'{where} must contain only path and sha256')
    require(isinstance(ref['sha256'], str) and re.fullmatch('[0-9a-f]{64}', ref['sha256']),
            f'invalid SHA-256: {where}')
    actual = digest(root, ref['path'])
    require(actual == ref['sha256'], f'stale reference hash: {where}')
    inventory[ref['path']] = actual
    return ref['path']


def identity(document, mapping, where):
    for field in ('design_id', 'revision'):
        require(document.get(field) == mapping[field], f'{where} {field} mismatch')


def graph_nodes(document):
    """Catalog top nodes and scoped repeat instances; no tensor/dataflow proof."""
    require(document.get('schema') == 'llm2rtl.model_graph.v1', 'unsupported graph schema')
    templates = obj(document.get('templates', {}), 'templates')
    result, graph_ids = set(), set()

    def walk(nodes, graph_id, prefix='', stack=()):
        local = set()
        for node in array(nodes, 'nodes'):
            obj(node, 'node')
            name = identifier(node.get('id'), 'node.id')
            require(name not in local, f'duplicate node ID: {graph_id}/{prefix}{name}')
            local.add(name)
            result.add((graph_id, prefix + name))
            if node.get('op') != 'repeat_template':
                continue
            attrs = obj(node.get('attributes'), 'repeat attributes')
            template = identifier(attrs.get('template_id'), 'template_id')
            require(template in templates, f'unknown template: {template}')
            require(template not in stack, f'recursive template: {template}')
            body = obj(templates[template], template)
            bindings = array(attrs.get('bindings'), 'repeat bindings')
            count = attrs.get('count')
            require(type(count) is int and count > 0 and count == len(bindings),
                    'repeat count must match explicit nonempty bindings')
            instances = set()
            for binding in bindings:
                obj(binding, 'binding')
                instance = identifier(binding.get('instance_id'), 'instance_id')
                require(instance not in instances, f'duplicate instance: {instance}')
                instances.add(instance)
                walk(body.get('nodes'), graph_id, prefix + name + '/' + instance + '/',
                     stack + (template,))
        require(local, 'empty graph/template nodes')

    for graph in array(document.get('graphs'), 'graphs'):
        obj(graph, 'graph')
        name = identifier(graph.get('id'), 'graph.id')
        require(name not in graph_ids, f'duplicate graph ID: {name}')
        graph_ids.add(name)
        walk(graph.get('nodes'), name)
    require(graph_ids, 'empty graphs')
    return result


def node_refs(value, known, where):
    result = set()
    for ref in array(value, where):
        obj(ref, where)
        require(set(ref) == {'graph_id', 'node_id'}, f'invalid node reference: {where}')
        pair = (text(ref['graph_id'], where), text(ref['node_id'], where))
        require(pair in known, f'unknown graph/node reference: {pair}')
        require(pair not in result, f'duplicate node reference: {where}: {pair}')
        result.add(pair)
    return result


def check_user_approval(root, mapping_path, mapping, expected_approval, inventory):
    """Check a recorded user decision, not the authenticity of a human identity."""
    require(isinstance(expected_approval, str) and re.fullmatch('[0-9a-f]{64}', expected_approval),
            'packet-provided approval SHA-256 required')
    approval_path = Path(mapping_path).with_name('module_mapping_approval.json').as_posix()
    actual = digest(root, approval_path)
    require(actual == expected_approval, 'packet approval SHA-256 mismatch')
    inventory[approval_path] = actual
    approval = read(root, approval_path)
    require(approval.get('schema') == 'llm2rtl.module_mapping_approval.v1',
            'unsupported mapping approval schema')
    identity(approval, mapping, 'approval')
    require(approval.get('path_base') == 'repository_root', 'approval path_base must be repository_root')
    require(approval.get('module_mapping') == {
        'path': mapping_path, 'sha256': inventory[mapping_path]},
        'user approval is not for this exact mapping; obtain fresh user confirmation')
    require(approval.get('decision') == 'approved', 'explicit user approval required')
    require(approval.get('scope') == 'implement_this_mapping', 'mapping implementation approval scope required')
    text(approval.get('recorded_by'), 'approval.recorded_by')
    request = obj(approval.get('request'), 'approval.request')
    response = obj(approval.get('user_response'), 'approval.user_response')
    require(response.get('actor') == 'user', 'Parent review cannot substitute for user approval')
    for name, message in (('request', request), ('user_response', response)):
        text(message.get('message_ref'), f'approval.{name}.message_ref')
        text(message.get('text'), f'approval.{name}.text')
    return approval_path


def check(root, mapping_path, bringup_path=None, expected_mapping=None,
          expected_bringup=None, stage_id=None, module_id=None, expected_approval=None,
          before_bringup=False):
    root = Path(root).resolve()
    inventory = {mapping_path: digest(root, mapping_path)}
    require(Path(mapping_path).name == 'module_mapping.json', 'canonical module_mapping.json required')
    if before_bringup:
        require(bringup_path is None and expected_bringup is None
                and stage_id is None and module_id is None,
                '--before-bringup cannot be combined with plan/stage/module consumption')
        target = root / Path(mapping_path).with_name('bringup.json')
        require(not target.exists() and not target.is_symlink(),
                'bringup.json already exists; preserve prior evidence and check the existing plan')
    if expected_mapping is not None:
        require(expected_mapping == inventory[mapping_path], 'packet mapping SHA-256 mismatch')
    mapping = read(root, mapping_path)
    require(mapping.get('schema') == 'llm2rtl.module_mapping.v1', 'unsupported mapping schema')
    for field in ('design_id', 'revision'):
        identifier(mapping.get(field), field)
    require(mapping.get('path_base') == 'repository_root', 'mapping path_base must be repository_root')
    require(mapping.get('status') in ('draft', 'blocked', 'reviewed'), 'invalid mapping status')
    scope = mapping.get('scope')
    require(scope in ('model', 'operator'), 'explicit model/operator scope required')
    source_field = 'model_graph' if scope == 'model' else 'operator_spec'
    require(('operator_spec' if scope == 'model' else 'model_graph') not in mapping,
            'model/operator sources must not be mixed')
    source_path = reference(root, mapping.get(source_field), source_field, inventory)
    if scope == 'model':
        require(Path(source_path) == Path(mapping_path).with_name('model_graph.json'),
                'model_graph.json must share the mapping planning directory')
        graph = read(root, source_path)
        identity(graph, mapping, 'graph')
        known = graph_nodes(graph)
    else:
        text(mapping.get('scope_reason'), 'operator scope_reason')
        known = set()  # A standalone operator must not invent model graph IDs.
    reference(root, mapping.get('hardware_profile'), 'hardware_profile', inventory)
    for field in ('architecture', 'numeric_policy', 'memory_plan'):
        require(obj(mapping.get(field), field), f'nonempty {field} required')
    review = obj(mapping.get('review'), 'review')
    limitations = array(review.get('limitations'), 'review.limitations')
    for limitation in limitations:
        text(limitation, 'review limitation')
    if mapping['status'] == 'reviewed':
        text(review.get('reviewed_by'), 'review.reviewed_by')
    if expected_mapping is not None:
        require(mapping['status'] == 'reviewed', 'packet consumption requires parent-reviewed mapping')

    modules = set()
    for module in array(mapping.get('modules'), 'modules'):
        obj(module, 'module')
        name = identifier(module.get('module_id'), 'module_id')
        require(name not in modules, f'duplicate module ID: {name}')
        modules.add(name)
        for field in ('role', 'rationale'):
            text(module.get(field), f'module.{field}')
        require(module.get('implementation') in ('generated', 'reused'),
                'module implementation must be generated or reused')
    require(modules, 'nonempty modules required')

    entries, covered, entry_ids = [], set(), set()
    for entry in array(mapping.get('mappings'), 'mappings'):
        obj(entry, 'mapping entry')
        name = identifier(entry.get('mapping_id'), 'mapping_id')
        require(name not in entry_ids, f'duplicate mapping ID: {name}')
        entry_ids.add(name)
        nodes = node_refs(entry.get('nodes'), known, name)
        require(scope == 'operator' or nodes, 'model mapping entry needs nodes')
        targets = ids(entry.get('module_ids'), 'mapping.module_ids')
        require(targets and targets <= modules, f'unknown/empty module IDs: {name}')
        for field in ('transform', 'rationale', 'numeric_validation'):
            text(entry.get(field), f'mapping.{field}')
        # Splitting one op over modules is one entry with multiple module IDs.
        require(not covered & nodes, 'node mapped more than once; use one split entry')
        covered |= nodes
        entries.append((nodes, targets))
    require(scope != 'operator' or entries, 'operator mapping needs at least one mapping entry')
    unmapped = {}
    for entry in array(mapping.get('unmapped_nodes'), 'unmapped_nodes'):
        obj(entry, 'unmapped node')
        pair = next(iter(node_refs([entry.get('node')], known, 'unmapped.node')))
        require(pair not in covered and pair not in unmapped, 'conflicting node disposition')
        require(entry.get('status') in ('blocked', 'excluded'), 'invalid unmapped status')
        text(entry.get('reason'), 'unmapped reason')
        unmapped[pair] = entry['status']
    require(covered | set(unmapped) == known,
            f'unaccounted graph nodes: {sorted(known - covered - set(unmapped))}')

    stages, selected_modules, selected_nodes = {}, set(), set()
    if bringup_path is not None:
        require(Path(bringup_path) == Path(mapping_path).with_name('bringup.json'),
                'bringup.json must share the mapping planning directory')
        inventory[bringup_path] = digest(root, bringup_path)
        if expected_bringup is not None:
            require(expected_bringup == inventory[bringup_path], 'packet bringup SHA-256 mismatch')
        plan = read(root, bringup_path)
        require(plan.get('schema') == 'llm2rtl.bringup.v1', 'unsupported bringup schema')
        identity(plan, mapping, 'bringup')
        require(('operator_spec' if scope == 'model' else 'model_graph') not in plan,
                'bringup model/operator sources must not be mixed')
        linked = reference(root, plan.get('module_mapping'), 'bringup.module_mapping', inventory)
        require(linked == mapping_path, 'bringup references a different mapping')
        for field in (source_field, 'hardware_profile'):
            require(plan.get(field) == mapping[field], f'bringup {field} mismatch')
        target = obj(plan.get('target'), 'target')
        target_nodes = node_refs(target.get('nodes'), known, 'target.nodes')
        require(scope == 'operator' or target_nodes, 'model target must not be empty')
        require(not {n for n in target_nodes if unmapped.get(n) == 'excluded'},
                'excluded nodes cannot remain in the requested target')
        previous, available = set(), set()
        for stage in array(plan.get('stages'), 'stages'):
            obj(stage, 'stage')
            name = identifier(stage.get('stage_id'), 'stage_id')
            require(name not in stages, f'duplicate stage ID: {name}')
            dependencies = ids(stage.get('depends_on'), 'depends_on')
            require(dependencies <= stages.keys(), 'stage dependency must refer to an earlier stage')
            if stages:
                require(next(reversed(stages)) in dependencies,
                        'cumulative stage must depend on the previous stage')
            new = ids(stage.get('new_modules'), 'new_modules')
            reused = ids(stage.get('reused_modules'), 'reused_modules')
            require(new <= modules and not new & available, 'unknown or already introduced new module')
            require(reused == available, 'cumulative stage must retain all prior modules')
            available |= new
            coverage = obj(stage.get('graph_coverage'), 'graph_coverage')
            added = node_refs(coverage.get('added'), known, 'coverage.added')
            cumulative = node_refs(coverage.get('cumulative'), known, 'coverage.cumulative')
            require(not added & previous and cumulative == previous | added,
                    'coverage must add new nodes and preserve all previous nodes')
            require(cumulative <= target_nodes, 'stage coverage outside requested target')
            for nodes, targets in entries:
                if nodes & cumulative:
                    require(targets <= available, 'stage covers nodes before their modules are available')
            require(stage.get('hardware_checkpoint_required') is True,
                    'cumulative stages require a user hardware checkpoint')
            stages[name] = stage
            previous = cumulative
            if name == stage_id:
                selected_modules, selected_nodes = available.copy(), cumulative
        require(stages, 'nonempty stages required')
        require(previous == target_nodes, 'final stage does not cover requested target')

    require(expected_bringup is None or bringup_path is not None, '--expected-bringup-sha256 needs --bringup')
    if module_id is not None and stage_id is None:
        require(scope == 'operator' and bringup_path is None and expected_mapping is not None,
                'module without stage needs standalone operator scope and packet mapping SHA-256')
        require(module_id in modules, 'unknown operator module')
    if stage_id is not None:
        require(bringup_path is not None and stage_id in stages, 'unknown stage or missing bringup')
        require(expected_mapping is not None and expected_bringup is not None,
                'stage gate requires packet-provided mapping and bringup SHA-256')
        require(mapping['status'] == 'reviewed', 'stage gate requires parent-reviewed mapping')
        require(not selected_nodes & set(unmapped), 'selected stage contains blocked/unmapped nodes')
        if module_id is not None:
            require(module_id in selected_modules, 'module is not available in selected stage')

    require(expected_approval is None or expected_mapping is not None,
            '--expected-approval-sha256 requires --expected-mapping-sha256')
    if before_bringup or bringup_path is not None:
        require(expected_mapping is not None,
                'bringup generation/validation requires approved mapping and '
                '--expected-mapping-sha256 plus --expected-approval-sha256')
    approval_path = None
    if expected_mapping is not None:
        approval_path = check_user_approval(root, mapping_path, mapping, expected_approval, inventory)
    if bringup_path is not None:
        approved = reference(root, plan.get('module_mapping_approval'),
                             'bringup.module_mapping_approval', inventory)
        require(approved == approval_path
                and plan['module_mapping_approval']['sha256'] == expected_approval,
                'bringup must reference the checked mapping approval')

    # Detect changes while the documents were being read; concurrent edits are unsupported.
    require(all(digest(root, p) == h for p, h in inventory.items()), 'planning inputs changed during check')
    return {'status': 'passed_structure_only', 'scope': scope,
            'design_id': mapping['design_id'], 'revision': mapping['revision'],
            'mapping_status': mapping['status'], 'stage': stage_id,
            'bringup_generation_gate_passed': before_bringup,
            'stage_reference_gate_passed': stage_id is not None,
            'user_approval_declaration_checked': approval_path is not None,
            'approval_path': approval_path,
            'node_count': len(known), 'unmapped_node_count': len(unmapped),
            'module_count': len(modules), 'stage_count': len(stages), 'sha256': inventory,
            'limits': 'References/declared coverage and recorded approval only; user identity and message '
                      'authenticity and historical file creation order are not verified. This read-only gate '
                      'does not prevent out-of-band file writes. Parent must run the generation gate before '
                      'authoring bringup, honor actual user decisions and review semantics, numeric evidence, '
                      'contracts and prior user hardware checkpoints before dispatch. No model execution, '
                      'RTL behavior, resource fit or board signoff is proven.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--mapping', required=True)
    parser.add_argument('--bringup')
    parser.add_argument('--before-bringup', action='store_true',
                        help='require exact user approval and absent bringup.json before authoring it')
    parser.add_argument('--expected-mapping-sha256')
    parser.add_argument('--expected-bringup-sha256')
    parser.add_argument('--expected-approval-sha256')
    parser.add_argument('--stage')
    parser.add_argument('--module')
    args = parser.parse_args()
    try:
        result = check(args.root, args.mapping, args.bringup, args.expected_mapping_sha256,
                       args.expected_bringup_sha256, args.stage, args.module, args.expected_approval_sha256,
                       args.before_bringup)
        print(json.dumps(result, indent=2))
        return 0
    except (PlanningError, OSError, TypeError, KeyError, RecursionError) as error:
        print(json.dumps({'status': 'blocked', 'error': str(error)}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
