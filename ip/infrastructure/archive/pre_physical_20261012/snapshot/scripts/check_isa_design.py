#!/usr/bin/env python3
"""Validate one minimal model-trace/ISA/bank/interpreter design bundle."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


class DesignError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise DesignError(message)


def read_json(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, f'duplicate JSON key: {path.name}: {key}')
            result[key] = value
        return result
    try:
        value = json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique,
                           parse_constant=lambda item: (_ for _ in ()).throw(
                               DesignError(f'non-JSON number: {item}')))
    except (UnicodeError, json.JSONDecodeError) as error:
        raise DesignError(f'invalid JSON: {path}: {error}') from error
    require(isinstance(value, dict), f'JSON object required: {path.name}')
    return value


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def identifier(value, where):
    require(isinstance(value, str) and re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.:-]*', value),
            f'invalid identifier: {where}')
    return value


def text(value, where):
    require(isinstance(value, str) and value.strip(), f'nonempty text required: {where}')
    return value


def array(value, where):
    require(isinstance(value, list), f'list required: {where}')
    return value


def ref(root, value, expected_name, where, inventory):
    require(isinstance(value, dict) and set(value) == {'path', 'sha256'},
            f'{where} must contain path and sha256')
    relative = Path(value['path'])
    require(not relative.is_absolute() and '..' not in relative.parts
            and relative.as_posix() == value['path'], f'unsafe path: {where}')
    path = root / relative
    require(path.name == expected_name and path.is_file() and not path.is_symlink(),
            f'missing or noncanonical reference: {where}')
    actual = sha256(path)
    require(value['sha256'] == actual, f'stale SHA-256: {where}')
    inventory[value['path']] = actual
    return path


def common_inventory(root):
    checker_path = root / 'scripts/check_common_contracts.py'
    spec = importlib.util.spec_from_file_location('_minimal_common_contracts', checker_path)
    require(spec is not None and spec.loader is not None, 'cannot load common contract checker')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    try:
        return module.check(root)['contracts']
    except module.ContractError as error:
        raise DesignError(f'common contract gate failed: {error}') from error


def check(root, design_dir, module_id=None, expected_module_sha256=None):
    root = Path(root).resolve()
    design_dir = Path(design_dir)
    require(not design_dir.is_absolute() and '..' not in design_dir.parts,
            'design-dir must be repository-relative')
    base = root / design_dir
    require(base.is_dir() and not base.is_symlink(), 'missing design directory')
    paths = {name: base / filename for name, filename in {
        'trace': 'model_trace.json', 'isa': 'isa_spec.json',
        'banks': 'bank_layout.json', 'validation': 'isa_validation.json'}.items()}
    require(all(path.is_file() and not path.is_symlink() for path in paths.values()),
            'design requires model_trace.json, isa_spec.json, bank_layout.json and isa_validation.json')
    docs = {name: read_json(path) for name, path in paths.items()}
    schemas = {'trace': 'llm2rtl.model_trace.v1', 'isa': 'llm2rtl.isa_spec.v1',
               'banks': 'llm2rtl.bank_layout.v1', 'validation': 'llm2rtl.isa_validation.v1'}
    for name, schema in schemas.items():
        require(docs[name].get('schema') == schema, f'unsupported {name} schema')
    trace = docs['trace']
    design_id = identifier(trace.get('design_id'), 'design_id')
    revision = identifier(trace.get('revision'), 'revision')
    for name in ('isa', 'banks', 'validation'):
        require(docs[name].get('design_id') == design_id
                and docs[name].get('revision') == revision, f'{name} identity mismatch')

    inventory = {str(path.relative_to(root)): sha256(path) for path in paths.values()}
    common = common_inventory(root)
    # Existing exact three-contract revisions retain their original boundary.
    # New generated revisions pin the additive engine completion principle.
    declared_common = docs['isa'].get('common_contracts')
    legacy_common = {path: value for path, value in common.items()
                     if path != 'contracts/common/engine_completion_contract.json'}
    require(declared_common == common or declared_common == legacy_common,
            'isa_spec common contract identities are missing or stale')

    identity = docs['trace'].get('model_identity')
    require(isinstance(identity, dict), 'model_identity object required')
    for field in ('model_id', 'revision', 'transformers_version', 'source_path', 'source_sha256'):
        text(identity.get(field), f'model_identity.{field}')
    require(re.fullmatch(r'[0-9a-f]{64}', identity['source_sha256']),
            'model source SHA-256 required')

    operations = set()
    for operation in array(trace.get('operations'), 'operations'):
        require(isinstance(operation, dict), 'operation object required')
        op_id = identifier(operation.get('operation_id'), 'operation_id')
        require(op_id not in operations, f'duplicate operation: {op_id}')
        operations.add(op_id)
        text(operation.get('semantic_kind'), f'{op_id}.semantic_kind')
        text(operation.get('source_location'), f'{op_id}.source_location')
    require(operations, 'model trace operations cannot be empty')
    workloads = set()
    for workload in array(trace.get('workloads'), 'workloads'):
        require(isinstance(workload, dict), 'workload object required')
        workload_id = identifier(workload.get('workload_id'), 'workload_id')
        require(workload_id not in workloads, f'duplicate workload: {workload_id}')
        workloads.add(workload_id)
        referenced = set(array(workload.get('operations'), f'{workload_id}.operations'))
        require(referenced and referenced <= operations, f'unknown/empty workload operations: {workload_id}')
        require(isinstance(workload.get('conditions'), dict), 'workload conditions required')
    require(workloads, 'model trace workloads cannot be empty')
    array(trace.get('unobserved_paths'), 'unobserved_paths')
    array(trace.get('unsupported_paths'), 'unsupported_paths')

    isa = docs['isa']
    require(isa.get('status') == 'reviewed', 'isa_spec must be reviewed before consumption')
    require(isa.get('unresolved_decisions') == [], 'unresolved ISA decisions block implementation')
    transport = isa.get('command_transport')
    require(isinstance(transport, dict), 'command_transport required')
    require(transport.get('command_order_owner') == 'ps_software'
            and transport.get('residency_tiling_owner') == 'ps_software'
            and transport.get('recovery_policy_owner') == 'ps_software',
            'PS must own order, residency tiling and recovery')
    require(transport.get('pl_dispatcher_role') == 'route_execute_report_only',
            'dispatcher role mismatch')
    require(transport.get('request_protocol') == 'ready_valid'
            and transport.get('response_protocol') == 'ready_valid',
            'internal command interface must use ready_valid')
    require(transport.get('program_transport') == 'ps_preloaded_command_bram',
            'initial command transport must use a PS-preloaded command BRAM')
    require(transport.get('queue_policy') == 'no_ring_queue',
            'initial command transport must not use a streaming ring queue')
    require(transport.get('dispatch_policy') == 'strict_in_order_single_pc_scoreboard',
            'dispatcher must use the simple in-order single-PC scoreboard policy')
    require(transport.get('execution_policy')
            == 'issue_on_request_handshake_with_scoreboard_completion',
            'dispatcher must advance after request acceptance and track completion separately')
    require(transport.get('outstanding_policy')
            == 'bank_hazard_limited_multiple',
            'dispatcher must allow multiple nonconflicting outstanding commands')
    require(transport.get('pc_advance_event') == 'executor_command_acceptance',
            'PC must advance when the current command is accepted')
    require(transport.get('response_collection') == 'independent_of_current_pc',
            'responses must be collected independently of the current PC')
    require(transport.get('program_terminal_policy')
            == 'end_opcode_then_drain_outstanding',
            'END must drain all outstanding commands before DONE')
    require(transport.get('blocked_pc_policy') == 'stall_without_lookahead',
            'blocked or active PC must stall without examining later instructions')
    require(transport.get('program_publish_order')
            == ['instruction_records_ending_in_END', 'start'],
            'program publish order must be END-terminated records then start')
    require(transport.get('mutation_while_busy') == 'forbidden',
            'PS program mutation while PL is busy must be forbidden')

    allowed_kinds = {'external_ddr_address', 'local_bank_id', 'dimension', 'stride',
                     'flags', 'transfer_length', 'format', 'scalar', 'tag',
                     'local_raw_address', 'local_bank_base', 'local_bank_offset'}
    opcodes, opcode_modules = set(), {}
    for opcode in array(isa.get('opcodes'), 'opcodes'):
        require(isinstance(opcode, dict), 'opcode object required')
        name = identifier(opcode.get('opcode'), 'opcode')
        require(name not in opcodes, f'duplicate opcode: {name}')
        opcodes.add(name)
        opcode_modules[name] = identifier(opcode.get('module_id'), f'{name}.module_id')
        opcode_class = opcode.get('opcode_class')
        require(opcode_class in ('dma_load', 'dma_store', 'compute', 'control',
                                 'compound_dma_compute'),
                f'invalid opcode class: {name}')
        kinds = []
        operand_names = set()
        for operand in array(opcode.get('operands'), f'{name}.operands'):
            require(isinstance(operand, dict) and set(operand) == {'name', 'kind'},
                    f'invalid operand declaration: {name}')
            operand_name = identifier(operand.get('name'), f'{name}.operand')
            require(operand_name not in operand_names, f'duplicate operand: {name}.{operand_name}')
            operand_names.add(operand_name)
            require(operand.get('kind') in allowed_kinds, f'invalid operand kind: {name}')
            kinds.append(operand['kind'])
        external = kinds.count('external_ddr_address')
        banks = kinds.count('local_bank_id')
        raw_local = any(kind in kinds for kind in
                        ('local_raw_address', 'local_bank_base', 'local_bank_offset'))
        if opcode_class == 'dma_load':
            require(name == 'DMA_LOAD' and external == 1 and banks >= 1,
                    'DMA_LOAD requires one DDR address and destination bank')
        elif opcode_class == 'dma_store':
            require(name == 'DMA_STORE' and external == 1 and banks >= 1,
                    'DMA_STORE requires source bank and one DDR address')
        elif opcode_class == 'compute':
            require(external == 0 and not raw_local and banks >= 1,
                    f'compute uses bank IDs only: {name}')
        elif opcode_class == 'compound_dma_compute':
            require(name == 'GEMM_TILES' and external == 1 and banks == 3
                    and not raw_local and opcode_modules[name] == 'isa_command_dispatcher',
                    'GEMM_TILES requires one DDR weight base and three bank IDs')
        else:
            require(external == 0, f'control cannot use DDR address: {name}')
        require(name in ('DMA_LOAD', 'DMA_STORE', 'GEMM_TILES') or external == 0,
                f'only DMA_LOAD/DMA_STORE/GEMM_TILES may use DDR address: {name}')
        for field in ('operand_semantics', 'completion_semantics', 'failure_semantics'):
            text(opcode.get(field), f'{name}.{field}')
    require(opcodes, 'opcodes cannot be empty')
    require('END' in opcodes, 'terminal END control opcode required')

    ownership = docs['banks'].get('ownership_model')
    require(isinstance(ownership, dict)
            and ownership.get('mode') == 'single_exclusive_lock_per_bank',
            'bank layout must use one exclusive acquire/release lock per bank')
    bank_ids = set()
    for bank in array(docs['banks'].get('banks'), 'banks'):
        require(isinstance(bank, dict), 'bank object required')
        bank_id = identifier(bank.get('bank_id'), 'bank_id')
        require(bank_id not in bank_ids, f'duplicate bank: {bank_id}')
        bank_ids.add(bank_id)
        require(type(bank.get('capacity_words')) is int and bank['capacity_words'] > 0,
                f'positive bank capacity required: {bank_id}')
        require(type(bank.get('word_bits')) is int and bank['word_bits'] > 0,
                f'positive bank word_bits required: {bank_id}')
        for field in ('format', 'layout'):
            text(bank.get(field), f'{bank_id}.{field}')
        array(bank.get('producers'), f'{bank_id}.producers')
        array(bank.get('consumers'), f'{bank_id}.consumers')
    require(bank_ids, 'bank layout cannot be empty')

    validation = docs['validation']
    for field, filename in (('model_trace', 'model_trace.json'), ('isa_spec', 'isa_spec.json'),
                            ('bank_layout', 'bank_layout.json')):
        linked = ref(root, validation.get(field), filename, f'validation.{field}', inventory)
        require(linked == paths[{'model_trace': 'trace', 'isa_spec': 'isa',
                                 'bank_layout': 'banks'}[field]], f'{field} reference mismatch')
    require(validation.get('status') == 'passed', 'ISA interpreter validation must pass')
    require(validation.get('no_host_tensor_compute') is True,
            'host tensor compute is forbidden')
    lowered = set()
    for lowering in array(validation.get('lowerings'), 'lowerings'):
        require(isinstance(lowering, dict), 'lowering object required')
        operation_id = lowering.get('operation_id')
        require(operation_id in operations and operation_id not in lowered,
                f'unknown or duplicate lowering: {operation_id}')
        lowered.add(operation_id)
        instructions = array(lowering.get('instructions'), f'{operation_id}.instructions')
        require(instructions, f'operation has no ISA instructions: {operation_id}')
        for instruction in instructions:
            require(isinstance(instruction, dict), 'instruction object required')
            require(instruction.get('opcode') in opcodes,
                    f'unknown opcode in lowering: {operation_id}')
            for bank_id in array(instruction.get('banks', []), 'instruction.banks'):
                require(bank_id in bank_ids, f'unknown bank in lowering: {bank_id}')
    require(lowered == operations, f'unlowered model operations: {sorted(operations - lowered)}')
    results = {}
    for result in array(validation.get('workload_results'), 'workload_results'):
        require(isinstance(result, dict), 'workload result object required')
        workload_id = result.get('workload_id')
        require(workload_id in workloads and workload_id not in results,
                f'unknown or duplicate workload result: {workload_id}')
        require(result.get('status') == 'passed', f'workload did not pass: {workload_id}')
        text(result.get('vector_sha256'), f'{workload_id}.vector_sha256')
        require(re.fullmatch(r'[0-9a-f]{64}', result['vector_sha256']),
                f'invalid vector SHA-256: {workload_id}')
        results[workload_id] = result
    require(set(results) == workloads, f'missing workload results: {sorted(workloads - set(results))}')
    require(validation.get('model_source_sha256') == identity['source_sha256'],
            'validation model source identity mismatch')

    module_checked = None
    if module_id is not None or expected_module_sha256 is not None:
        module_id = identifier(module_id, 'module argument')
        require(isinstance(expected_module_sha256, str)
                and re.fullmatch(r'[0-9a-f]{64}', expected_module_sha256),
                'expected module SHA-256 required')
        module_path = base / 'modules' / f'{module_id}.json'
        require(module_path.is_file() and not module_path.is_symlink(), 'missing module contract')
        require(sha256(module_path) == expected_module_sha256, 'module contract SHA-256 mismatch')
        module = read_json(module_path)
        require(module.get('schema') == 'llm2rtl.module_contract.v1',
                'unsupported module contract schema')
        require(module.get('design_id') == design_id and module.get('revision') == revision
                and module.get('module_id') == module_id, 'module identity mismatch')
        module_kind = module.get('module_kind', 'opcode_executor')
        require(module_kind in ('opcode_executor', 'infrastructure'),
                'module_kind must be opcode_executor or infrastructure')
        if module_kind == 'opcode_executor':
            opcode = module.get('opcode')
            require(opcode in opcodes and opcode_modules[opcode] == module_id,
                    'module does not implement its ISA opcode')
        else:
            require(module.get('opcode') is None,
                    'infrastructure module must not claim an opcode')
            routed = array(module.get('routed_opcodes'), 'module.routed_opcodes')
            require(routed and len(routed) == len(set(routed)) and set(routed) <= opcodes,
                    'infrastructure module routed_opcodes must be unique known opcodes')
        require(module.get('status') == 'frozen', 'module contract must be frozen')
        for field in ('interface', 'numeric', 'verification'):
            require(isinstance(module.get(field), dict) and module[field],
                    f'nonempty module {field} contract required')
        module_checked = str(module_path.relative_to(root))
        inventory[module_checked] = expected_module_sha256

    return {'status': 'passed_structure_only', 'design_id': design_id, 'revision': revision,
            'operation_count': len(operations), 'workload_count': len(workloads),
            'opcode_count': len(opcodes), 'bank_count': len(bank_ids),
            'module_checked': module_checked, 'inventory': inventory,
            'engine_completion_contract_pinned': declared_common == common,
            'limitations': 'Structure and declared identity only; no numerical, RTL, Vivado, or board proof.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', default=str(ROOT))
    parser.add_argument('--design-dir', required=True)
    parser.add_argument('--module')
    parser.add_argument('--expected-module-sha256')
    args = parser.parse_args()
    try:
        print(json.dumps(check(args.root, args.design_dir, args.module,
                               args.expected_module_sha256), indent=2))
    except (DesignError, OSError, TypeError, KeyError) as error:
        print(json.dumps({'status': 'failed', 'error': str(error)}))
        raise SystemExit(1)
