#!/usr/bin/env python3
"""Create, freeze and consume source-bound design contract bundles (stdlib only)."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAMES = ('address_ownership', 'memory_ownership', 'native_memory_timing',
         'block_design_layout', 'model_scheduler_role')
POLICIES = ['contracts/generation_policy.json'] + [f'contracts/{n}.json' for n in NAMES]
ENGINE = 'ip/infrastructure/datamover_engine'
# Explicit inventory: deleting a source must fail, not silently shrink a glob.
ENGINE_RTL = ('axis_width_converter axis_width_down_converter axis_width_up_converter '
              'bank_arbiter bank_read_arbit bank_write_arbit bram_bank uram_bank '
              'datamover_engine datamover_engine_pkg datamover_command_queue fifo pipeline '
              'mm2s_adapter mm2s_channel s2mm_adapter s2mm_channel status_decoder').split()


def transport_files(root, index, docs):
    transport = index.get('transport')
    require(isinstance(transport, dict), 'explicit transport declaration required')
    enabled = transport.get('ddr_local_transfers')
    require(type(enabled) is bool, 'ddr_local_transfers must be a boolean')
    complete(transport, 'index.transport')
    external = []
    for file in index['module_contracts'].values():
        transfers = docs[file].get('variant', {}).get('external_transfers', {})
        require(isinstance(transfers, dict), 'external_transfers must be an object')
        external.extend(transfers.values())
    if not enabled:
        require(set(transport) == {'ddr_local_transfers', 'reason'},
                'non-DDR declaration requires only boolean and reason')
        require(isinstance(transport['reason'], str), 'non-DDR reason must be text')
        require(not external, 'external transfers conflict with non-DDR declaration')
        return set()
    require(transport.get('engine') == ENGINE, 'bundled DataMover Engine is mandatory')
    require(transport.get('interface_contract') == ENGINE + '/interface_contract.json',
            'bundled DataMover interface contract required')
    for key in ('command_owner', 'error_policy_owner'):
        require(transport.get(key) == 'model_scheduler', f'{key} must be model_scheduler')
    connections = transport.get('connections')
    require(isinstance(connections, dict) and
            set(connections) == {'command', 'completion', 'ddr', 'local_memory'},
            'command/completion/ddr/local_memory connections required')
    for name, endpoints in connections.items():
        require(isinstance(endpoints, dict) and set(endpoints) == {'source', 'sink'},
                f'connection endpoints required: {name}')
        for endpoint in endpoints.values():
            require(isinstance(endpoint, str) and endpoint.strip(),
                    f'connection endpoint must be text: {name}')
        require(endpoints['source'] != endpoints['sink'], f'self connection: {name}')
    require(isinstance(transport.get('integration_verification'), str),
            'integration verification plan required')
    for transfer in external:
        require(isinstance(transfer, dict) and transfer.get('transport') == 'datamover_engine',
                'inline external transfer must use datamover_engine')
        require(transfer.get('direction') in ('ddr_to_local', 'local_to_ddr'),
                'unsupported external transfer direction')
    files = {ENGINE + '/interface_contract.json'}
    files.update(f'{ENGINE}/rtl/{name}.sv' for name in ENGINE_RTL)
    for file in files:
        require(path(root, file).is_file(), f'missing DataMover dependency: {file}')
    return files


class ContractError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ContractError(message)


def identifier(value):
    require(isinstance(value, str) and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', value),
            f'invalid identifier: {value!r}')
    return value


def path(root, value):
    require(isinstance(value, str) and value.strip(), 'missing path')
    rel = Path(value)
    require(not rel.is_absolute() and '..' not in rel.parts, f'unsafe path: {value}')
    current = root
    for part in rel.parts:
        current = current / part
        require(not current.is_symlink(), f'symlink forbidden: {value}')
    require(current.resolve().is_relative_to(root.resolve()), f'outside root: {value}')
    return current


def read(root, value):
    p = path(root, value)
    require(p.is_file(), f'missing file: {value}')
    try:
        result = json.loads(p.read_text())
    except (ValueError, UnicodeError) as e:
        raise ContractError(f'invalid JSON: {value}: {e}') from e
    require(isinstance(result, dict), f'object required: {value}')
    return result


def sha(root, value):
    return hashlib.sha256(path(root, value).read_bytes()).hexdigest()


def write_new(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open('x') as f:
        json.dump(value, f, indent=2)
        f.write('\n')


def complete(value, location='contract'):
    """Structural completion, not proof of domain semantics."""
    require(value is not None, f'unresolved null: {location}')
    if isinstance(value, str):
        require(value.strip() and value.strip().lower() not in ('todo', 'tbd', 'pending')
                and not re.search(r'<[^>]+>', value), f'placeholder: {location}')
    elif isinstance(value, dict):
        require(value, f'empty object: {location}')
        if value.get('not_applicable') is True:
            require(set(value) == {'not_applicable', 'reason', 'approved_by'},
                    f'invalid exemption: {location}')
            for key in ('reason', 'approved_by'):
                require(isinstance(value[key], str), f'invalid exemption {key}')
                complete(value[key], location + '.' + key)
        else:
            for k, v in value.items():
                complete(v, location + '.' + k)
    elif isinstance(value, list):
        require(value, f'empty list: {location}; use a justified exemption if inapplicable')
        for i, v in enumerate(value):
            complete(v, f'{location}[{i}]')


def shape(value, template, location):
    if isinstance(value, dict) and value.get('not_applicable') is True:
        complete(value, location)
        return
    if isinstance(template, dict):
        require(isinstance(value, dict), f'object required: {location}')
        require(set(template) <= set(value), f'missing template fields: {location}')
        for k, v in template.items():
            shape(value[k], v, location + '.' + k)
    elif isinstance(template, list):
        require(isinstance(value, list) and value, f'nonempty list required: {location}')
        if template:
            for i, v in enumerate(value):
                shape(v, template[0], f'{location}[{i}]')


def init(root, design, revision, hardware, modules):
    identifier(design); identifier(revision)
    require(modules and len(set(modules)) == len(modules), 'unique module IDs required')
    for m in modules:
        identifier(m)
    read(root, hardware)
    folder = f'contracts/designs/{design}/{revision}'
    destination = path(root, folder)
    require(not destination.exists(), 'revision already exists; choose a fresh revision')
    index = read(root, 'contracts/templates/contract_index.json')
    templates = {n: read(root, f'contracts/templates/{n}.json') for n in NAMES}
    module_template = read(root, 'contracts/templates/module_contract.json')
    index.update(document_kind='design_contract_index', design_id=design, revision=revision,
                 hardware_profile=hardware, policies=POLICIES,
                 policy_applicability={p: 'applicable' for p in POLICIES},
                 design_contracts={n: f'{folder}/{n}.json' for n in NAMES},
                 module_contracts={m: f'{folder}/modules/{m}/contract.json' for m in modules})
    destination.mkdir(parents=True, exist_ok=False)
    for name, doc in templates.items():
        doc.update(document_kind='design_contract', design_id=design, revision=revision)
        write_new(path(root, index['design_contracts'][name]), doc)
    for name, file in index['module_contracts'].items():
        doc = dict(module_template, document_kind='module_contract', design_id=design,
                   revision=revision, module_id=name)
        write_new(path(root, file), doc)
    write_new(destination / 'contract_index.json', index)
    return folder + '/contract_index.json'


def inspect(root, index_path, frozen=True):
    index = read(root, index_path)
    design, rev = identifier(index.get('design_id')), identifier(index.get('revision'))
    folder = f'contracts/designs/{design}/{rev}/'
    require(index_path == folder + 'contract_index.json', 'index path/identity mismatch')
    require(index.get('document_kind') == 'design_contract_index', 'not a design index')
    require(index.get('path_base') == 'repository_root', 'wrong path base')
    require(index.get('status') == ('frozen' if frozen else 'draft'), 'wrong index status')
    require(index.get('policies') == POLICIES, 'policy inventory mismatch')
    applicability = index.get('policy_applicability')
    require(isinstance(applicability, dict) and set(applicability) == set(POLICIES),
            'policy applicability inventory mismatch')
    for p, choice in applicability.items():
        require(choice == 'applicable' or
                (isinstance(choice, dict) and choice.get('not_applicable') is True),
                f'invalid policy applicability: {p}')
        complete(choice, p)
    require(applicability['contracts/generation_policy.json'] == 'applicable',
            'generation policy cannot be exempted')
    complete(index.get('verification_plan'), 'index.verification_plan')
    if frozen:
        complete(index.get('approved_by'), 'index.approved_by')
    docs = {}
    files = set(POLICIES + ['contracts/templates/contract_index.json',
                          'contracts/templates/module_contract.json'])
    for p in POLICIES:
        policy = read(root, p)
        for key in ('job_control_contract',):
            if key in policy:
                require(path(root, policy[key]).is_file(), f'missing policy dependency: {key}')
                files.add(policy[key])
    read(root, index.get('hardware_profile'))
    files.add(index['hardware_profile'])
    design_docs = index.get('design_contracts')
    require(isinstance(design_docs, dict) and set(design_docs) == set(NAMES),
            'design contract inventory mismatch')
    modules = index.get('module_contracts')
    require(isinstance(modules, dict) and modules, 'module contracts required')
    entries = [(n, f, f'contracts/templates/{n}.json', False) for n, f in design_docs.items()]
    entries += [(n, f, 'contracts/templates/module_contract.json', True) for n, f in modules.items()]
    for name, file, template_path, module in entries:
        identifier(name)
        expected = folder + (f'modules/{name}/contract.json' if module else f'{name}.json')
        require(file == expected, f'contract outside selected design/revision: {file}')
        doc, template = read(root, file), read(root, template_path)
        shape(doc, template, file)
        complete(doc, file)
        require(doc.get('document_kind') == ('module_contract' if module else 'design_contract'),
                f'wrong contract kind: {file}')
        # A failed freeze may have updated some documents but not the draft index.
        # Revalidate every document before resuming; consumers still require a frozen index.
        allowed_status = ('frozen',) if frozen else ('draft', 'frozen')
        require(doc.get('status') in allowed_status, f'wrong status: {file}')
        require((doc.get('design_id'), doc.get('revision')) == (design, rev),
                f'contract identity mismatch: {file}')
        if module:
            require(doc.get('module_id') == name, f'module identity mismatch: {file}')
            # This optional payload is inline so the frozen bundle binds the exact variant.
            if 'variant' in doc:
                require(isinstance(doc['variant'], dict), 'variant must be an inline object')
        else:
            require(doc.get('policy') == f'contracts/{name}.json', f'policy mismatch: {file}')
        docs[file] = doc
        files.update((file, template_path))
    files.update(transport_files(root, index, docs))
    hashes = {f: sha(root, f) for f in sorted(files)}
    if frozen:
        require(index.get('sha256') == hashes, 'frozen dependency hash mismatch')
    return index, docs, hashes


def freeze(root, index_path, approved_by):
    complete(approved_by, 'approved_by')
    index, docs, _ = inspect(root, index_path, frozen=False)
    # Authority is an explicit parent declaration, not a cryptographic identity check.
    for file, doc in docs.items():
        doc['status'] = 'frozen'
        atomic_write(path(root, file), doc)
    index.update(status='frozen', approved_by=approved_by)
    files = inspect_file_inventory(root, index, docs)
    index['sha256'] = {f: sha(root, f) for f in sorted(files)}
    # Commit the index last and atomically so an interrupted index write cannot
    # destroy the draft or publish partial JSON. No concurrent editing is supported.
    atomic_write(path(root, index_path), index)
    inspect(root, index_path)
    return sha(root, index_path)


def atomic_write(destination, document):
    fd, temporary = tempfile.mkstemp(prefix='.contract-freeze-', dir=destination.parent)
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(document, f, indent=2)
            f.write('\n')
            f.flush()
            os.fsync(f.fileno())
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def inspect_file_inventory(root, index, docs):
    files = set(index['policies'] + [index['hardware_profile'],
                'contracts/templates/contract_index.json', 'contracts/templates/module_contract.json'])
    files.update(docs)
    files.update(transport_files(root, index, docs))
    files.update(f'contracts/templates/{n}.json' for n in NAMES)
    for p in index['policies']:
        policy = read(root, p)
        if 'job_control_contract' in policy:
            files.add(policy['job_control_contract'])
    return files


def consume(root, index_path, expected_sha256, module=None):
    require(isinstance(expected_sha256, str) and re.fullmatch('[0-9a-f]{64}', expected_sha256),
            'parent-provided index SHA-256 required')
    require(sha(root, index_path) == expected_sha256, 'index SHA-256 mismatch')
    index, docs, hashes = inspect(root, index_path)
    if module is not None:
        require(module in index['module_contracts'], f'unknown module: {module}')
    # Return loaded documents, not merely paths: consumers receive the checked payloads.
    result = {'status': 'passed', 'design_id': index['design_id'], 'revision': index['revision'],
              'index': index_path, 'index_sha256': expected_sha256, 'sha256': hashes,
              'policies': {p: read(root, p) for p in POLICIES},
              'hardware_profile': read(root, index['hardware_profile']), 'contracts': docs}
    if module:
        result['module'] = docs[index['module_contracts'][module]]
    require(sha(root, index_path) == expected_sha256, 'index changed during consumption')
    require(all(sha(root, p) == h for p, h in hashes.items()), 'dependency changed during consumption')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('init')
    create.add_argument('--design-id', required=True)
    create.add_argument('--revision', required=True)
    create.add_argument('--hardware-profile', required=True)
    create.add_argument('--module', action='append', required=True)
    seal = commands.add_parser('freeze')
    seal.add_argument('--index', required=True)
    seal.add_argument('--approved-by', required=True)
    check = commands.add_parser('check')
    check.add_argument('--index', required=True)
    check.add_argument('--expected-sha256', required=True)
    check.add_argument('--module')
    args = parser.parse_args()
    try:
        root = args.root.resolve()
        if args.command == 'init':
            result = {'status': 'draft_created', 'index': init(root, args.design_id, args.revision,
                                                            args.hardware_profile, args.module)}
        elif args.command == 'freeze':
            result = {'status': 'frozen', 'index': args.index,
                      'index_sha256': freeze(root, args.index, args.approved_by)}
        else:
            result = consume(root, args.index, args.expected_sha256, args.module)
        print(json.dumps(result, indent=2))
        return 0
    except (ContractError, OSError, TypeError, KeyError) as error:
        print(json.dumps({'status': 'blocked', 'error': str(error)}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
