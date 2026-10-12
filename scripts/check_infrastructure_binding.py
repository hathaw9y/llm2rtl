#!/usr/bin/env python3
"""Check reusable infrastructure templates and a model-specific fabric binding."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
_SOURCE_SPEC = importlib.util.spec_from_file_location('binding_source_relocation', ROOT / 'scripts/infrastructure_sources.py')
_SOURCES = importlib.util.module_from_spec(_SOURCE_SPEC)
_SOURCE_SPEC.loader.exec_module(_SOURCES)
OWNERSHIP_TEMPLATE = Path('ip/infrastructure/contracts/ownership_template.json')
FABRIC_TEMPLATE = Path('ip/infrastructure/contracts/fabric_template.json')
LEGACY_OWNERSHIP_TEMPLATE = Path('ip/infrastructure/bank_ownership_table/template_contract.json')
LEGACY_FABRIC_TEMPLATE = Path('ip/infrastructure/execution_fabric_template/template_contract.json')


class BindingError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise BindingError(message)


def read_json(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, f'duplicate JSON key: {path}: {key}')
            result[key] = value
        return result
    value = json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique)
    require(isinstance(value, dict), f'JSON object required: {path}')
    return value


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe_path(root, relative):
    require(isinstance(relative, str) and relative, 'nonempty repository-relative path required')
    path = Path(relative)
    require(not path.is_absolute() and '..' not in path.parts and path.as_posix() == relative,
            f'unsafe path: {relative}')
    result = root / path
    if not result.exists() and relative.startswith('ip/infrastructure/'):
        try:
            return _SOURCES.resolve_reference(relative, root=root)
        except (_SOURCES.SourceError, OSError, ValueError) as error:
            raise BindingError(f'compatibility reference rejected: {error}') from error
    require(result.is_file() and not result.is_symlink(), f'missing regular file: {relative}')
    return result


def check_templates(root=ROOT):
    root = Path(root).resolve()
    active = (root / OWNERSHIP_TEMPLATE).exists() or (root / FABRIC_TEMPLATE).exists()
    ownership_path = OWNERSHIP_TEMPLATE if active else LEGACY_OWNERSHIP_TEMPLATE
    fabric_path = FABRIC_TEMPLATE if active else LEGACY_FABRIC_TEMPLATE
    ownership = read_json(safe_path(root, ownership_path.as_posix()))
    fabric = read_json(safe_path(root, fabric_path.as_posix()))
    require(ownership.get('schema') == 'llm2rtl.bank_ownership_template.v1',
            'invalid ownership template schema')
    require(fabric.get('schema') == ('llm2rtl.execution_fabric_template.v2' if active
                                   else 'llm2rtl.execution_fabric_template.v1'),
            'invalid fabric template schema')
    source = safe_path(root, ownership.get('implementation'))
    require(sha256(source) == ownership.get('implementation_sha256'),
            'ownership source SHA-256 mismatch')
    require(ownership.get('top') == 'bank_ownership_table', 'ownership top mismatch')
    required = {'model_specific_dispatcher', 'datamover_engine', 'bank_ownership_table',
                'local_bank_router_and_memories', 'dma_stream_bank_adapters',
                'model_specific_executors'}
    require(set(fabric.get('required_roles', [])) == required, 'fabric role inventory mismatch')
    pins = fabric.get('pinned_infrastructure')
    require(isinstance(pins, list) and len(pins) == 3, 'pinned infrastructure required')
    for pin in pins:
        require(isinstance(pin, dict) and set(pin) == {'path', 'sha256'},
                'invalid infrastructure pin')
        require(sha256(safe_path(root, pin['path'])) == pin['sha256'],
                f'infrastructure source SHA-256 mismatch: {pin["path"]}')
    engine_index_path = fabric.get('datamover_source_index')
    require(isinstance(engine_index_path, str) and (
            engine_index_path == 'ip/infrastructure/contracts/datamover_source_index.json'
            if active else
            engine_index_path.startswith('ip/infrastructure/datamover_engine/evidence/engine/')
            and engine_index_path.endswith('/integration_source_index.json')),
            'DataMover source-closure index path required')
    require(any(pin['path'] == engine_index_path for pin in pins),
            'DataMover source-closure index pin required')
    engine_index = read_json(safe_path(root, engine_index_path))
    require(engine_index.get('module_id') == 'datamover_engine'
            and engine_index.get('top') == 'datamover_engine',
            'invalid DataMover source-closure index')
    if active:
        require(engine_index.get('schema') == 'llm2rtl.infrastructure_active_source_index.v1',
                'invalid active DataMover source-closure schema')
        require(engine_index.get('evidence_scope') == 'source_identity_only_new_signoff_required'
                and 'verification' not in engine_index,
                'active DataMover index must not inherit historical verification')
    source_order = engine_index.get('source_order')
    require(isinstance(source_order, list) and source_order, 'DataMover source order required')
    source_paths = set()
    for source_record in source_order:
        require(isinstance(source_record, dict) and set(source_record) == {'path', 'sha256'},
                'invalid DataMover source record')
        require(source_record['path'] not in source_paths, 'duplicate DataMover source path')
        source_paths.add(source_record['path'])
        require(sha256(safe_path(root, source_record['path'])) == source_record['sha256'],
                f'DataMover source SHA-256 mismatch: {source_record["path"]}')
    engine_contract = engine_index.get('contract', {})
    require(sha256(safe_path(root, engine_contract['path'])) == engine_contract['sha256'],
            'DataMover interface contract SHA-256 mismatch')
    if not active:
        verification = engine_index.get('verification', {})
        for name in ('verification_report.json', 'captured_inputs.json', 'evidence_manifest.json'):
            record = verification.get(name, {})
            require(sha256(safe_path(root, record.get('path'))) == record.get('sha256'),
                    f'DataMover verification evidence SHA-256 mismatch: {name}')
    binding_path = safe_path(root, fabric.get('binding_template'))
    blank = read_json(binding_path)
    require(blank.get('schema') == 'llm2rtl.execution_fabric_binding.v1',
            'invalid blank binding schema')
    require(blank.get('design_dir') is None and blank.get('compute_routes') == [],
            'binding template must remain unbound')
    rtl_template = safe_path(root, fabric.get('rtl_template'))
    rtl = rtl_template.read_text(encoding='utf-8')
    for marker in ('TOP_MODULE', 'TOP_PORTS', 'SHARED_SIGNALS',
                   'DISPATCHER_INSTANCE', 'DATAMOVER_INSTANCE', 'OWNERSHIP_INSTANCE',
                   'BANK_SUBSYSTEM_INSTANCE', 'DMA_ADAPTER_INSTANCES',
                   'EXECUTOR_INSTANCES', 'INTEGRATION_ASSERTIONS'):
        require(rtl.count(f'@{marker}@') == 1, f'missing or duplicate RTL marker: {marker}')
    return {'status': 'passed_template_structure', 'ownership_source_sha256': sha256(source),
            'scope': 'compatibility_family_only_not_default_design_reference',
            'fabric_template_sha256': sha256(root / fabric_path),
            'evidence_scope': ('source_identity_only_new_signoff_required' if active
                               else 'historical_pinned_verification')}


def check_binding(root, binding_relative):
    root = Path(root).resolve()
    template_result = check_templates(root)
    binding = read_json(safe_path(root, binding_relative))
    require(binding.get('schema') == 'llm2rtl.execution_fabric_binding.v1',
            'invalid binding schema')
    design_dir = binding.get('design_dir')
    require(isinstance(design_dir, str) and design_dir.startswith('designs/')
            and '..' not in Path(design_dir).parts, 'design_dir must be repository-relative')
    design_base = root / design_dir
    require(design_base.is_dir() and not design_base.is_symlink(), 'missing design directory')
    isa_path = safe_path(root, f'{design_dir}/isa_spec.json')
    banks_path = safe_path(root, f'{design_dir}/bank_layout.json')
    require(binding.get('isa_spec_sha256') == sha256(isa_path), 'ISA SHA-256 mismatch')
    require(binding.get('bank_layout_sha256') == sha256(banks_path), 'bank layout SHA-256 mismatch')
    isa = read_json(isa_path)
    banks = read_json(banks_path)
    for doc in (isa, banks):
        require(doc.get('design_id') == binding.get('design_id')
                and doc.get('revision') == binding.get('revision'),
                'binding design/revision mismatch')
    require(isa.get('status') == 'reviewed' and isa.get('unresolved_decisions') == [],
            'ISA is not reviewed or has unresolved decisions')

    spec = importlib.util.spec_from_file_location('isa_design_gate', root / 'scripts/check_isa_design.py')
    require(spec is not None and spec.loader is not None, 'missing ISA checker')
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    try:
        checker.check(root, design_dir)
    except checker.DesignError as error:
        raise BindingError(f'ISA design gate failed: {error}') from error

    require('command_bank_id' not in banks,
            'command BRAM must not occupy the data-bank namespace')
    inventory = banks.get('banks')
    require(isinstance(inventory, list) and inventory, 'bank inventory required')
    bank_ids = [bank.get('numeric_id') for bank in inventory]
    require(all(type(value) is int for value in bank_ids)
            and sorted(bank_ids) == list(range(len(bank_ids))),
            'data bank numeric IDs must be contiguous from zero')
    bank_count = binding.get('bank_count')
    require(type(bank_count) is int and bank_count == len(bank_ids),
            'binding bank count does not match bank layout')
    width = binding.get('port_role_width')
    require(type(width) is int and width >= 3,
            'owner-role width must satisfy the pinned ownership RTL minimum of three')
    roles = binding.get('owner_roles')
    require(isinstance(roles, dict) and {'MM2S_ARBITER', 'S2MM_ARBITER'} <= set(roles),
            'DMA owner roles required')
    values = list(roles.values())
    require(all(type(value) is int and 0 < value < (1 << width) for value in values)
            and len(values) == len(set(values)), 'owner roles must be unique nonzero IDs in range')
    for key in ('dispatcher_module', 'bank_subsystem_module'):
        require(isinstance(binding.get(key), str)
                and re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', binding[key]),
                f'valid {key} required')

    caps = binding.get('bank_capabilities')
    require(isinstance(caps, list) and len(caps) == bank_count,
            'one capability record per bank required')
    cap_map = {}
    for cap in caps:
        require(isinstance(cap, dict) and set(cap) == {'bank_id', 'allowed_roles'},
                'invalid bank capability record')
        bank_id, allowed = cap['bank_id'], cap['allowed_roles']
        require(type(bank_id) is int and bank_id in bank_ids and bank_id not in cap_map,
                'unknown or duplicate capability bank')
        require(isinstance(allowed, list) and len(allowed) == len(set(allowed))
                and set(allowed) <= set(roles), 'invalid allowed owner roles')
        cap_map[bank_id] = set(allowed)
    require(set(cap_map) == set(bank_ids), 'missing bank capability record')

    compute = {op['opcode']: op for op in isa['opcodes'] if op['opcode_class'] == 'compute'}
    routes = binding.get('compute_routes')
    require(isinstance(routes, list), 'compute routes list required')
    seen = set()
    for route in routes:
        require(isinstance(route, dict)
                and set(route) == {'opcode', 'module_id', 'operand_roles'},
                'invalid compute route')
        opcode = route['opcode']
        require(opcode in compute and opcode not in seen, 'unknown or duplicate compute route')
        seen.add(opcode)
        require(route['module_id'] == compute[opcode]['module_id'],
                'compute route module mismatch')
        operands = {operand['name'] for operand in compute[opcode]['operands']
                    if operand['kind'] == 'local_bank_id'}
        mapped = route['operand_roles']
        require(isinstance(mapped, dict) and set(mapped) == operands
                and set(mapped.values()) <= set(roles)
                and len(mapped.values()) == len(set(mapped.values())),
                'compute operand role mapping incomplete')
        for role in mapped.values():
            require(any(role in allowed for allowed in cap_map.values()),
                    f'no bank supports compute role: {role}')
    require(seen == set(compute), f'missing compute routes: {sorted(set(compute)-seen)}')

    adapters = binding.get('dma_adapters')
    require(isinstance(adapters, list), 'DMA adapters list required')
    adapter_pairs = set()
    for item in adapters:
        require(isinstance(item, dict) and set(item) == {'bank_id', 'direction', 'module_id'},
                'invalid DMA adapter')
        bank_id, direction = item['bank_id'], item['direction']
        require(type(bank_id) is int and bank_id in cap_map
                and direction in ('load', 'store')
                and (bank_id, direction) not in adapter_pairs,
                'unknown or duplicate DMA adapter')
        require(isinstance(item['module_id'], str) and item['module_id'],
                'DMA adapter module required')
        role = 'MM2S_ARBITER' if direction == 'load' else 'S2MM_ARBITER'
        require(role in cap_map[bank_id], 'DMA adapter lacks matching bank capability')
        adapter_pairs.add((bank_id, direction))
    for bank_id, allowed in cap_map.items():
        for direction, role in (('load', 'MM2S_ARBITER'), ('store', 'S2MM_ARBITER')):
            require((role in allowed) == ((bank_id, direction) in adapter_pairs),
                    'DMA bank capability and adapter inventory disagree')

    boundaries = binding.get('external_boundaries')
    require(isinstance(boundaries, dict)
            and set(boundaries) == {'command_bram_port', 'vendor_datamover_ports',
                                   'ps_control_port'}
            and all(isinstance(value, str) and value.strip() for value in boundaries.values()),
            'external boundary declarations required')
    return dict(template_result, status='passed_binding_structure',
                design_id=binding['design_id'], revision=binding['revision'],
                bank_count=bank_count, compute_opcode_count=len(compute),
                limitations='Structure and declarations only; generated RTL and board remain unverified.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--binding', help='repository-relative model fabric binding JSON')
    args = parser.parse_args()
    try:
        result = check_binding(args.root, args.binding) if args.binding else check_templates(args.root)
        print(json.dumps(result, indent=2))
    except (BindingError, OSError, ValueError, TypeError, KeyError) as error:
        print(json.dumps({'status': 'failed', 'error': str(error)}))
        raise SystemExit(1)


if __name__ == '__main__':
    main()
