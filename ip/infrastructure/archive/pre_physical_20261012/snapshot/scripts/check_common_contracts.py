#!/usr/bin/env python3
"""Validate the small immutable architecture contracts."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    'isa_command': 'contracts/common/isa_command_contract.json',
    'local_bank': 'contracts/common/local_bank_contract.json',
    'evidence_identity': 'contracts/common/evidence_identity_contract.json',
    'engine_completion': 'contracts/common/engine_completion_contract.json',
}


class ContractError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ContractError(message)


def read_json(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, f'duplicate JSON key: {path}: {key}')
            result[key] = value
        return result

    try:
        return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique,
                          parse_constant=lambda value: (_ for _ in ()).throw(
                              ContractError(f'non-JSON number: {value}')))
    except (UnicodeError, json.JSONDecodeError) as error:
        raise ContractError(f'invalid JSON: {path}: {error}') from error


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(root=ROOT):
    root = Path(root).resolve()
    documents, inventory = {}, {}
    for contract_id, relative in FILES.items():
        path = root / relative
        require(path.is_file() and not path.is_symlink(), f'missing common contract: {relative}')
        document = read_json(path)
        require(document.get('schema') == 'llm2rtl.common_contract.v1',
                f'unsupported common contract schema: {relative}')
        require(document.get('contract_id') == contract_id, f'contract ID mismatch: {relative}')
        expected_version = 2 if contract_id == 'local_bank' else 1
        require(document.get('version') == expected_version,
                f'contract version mismatch: {relative}')
        documents[contract_id] = document
        inventory[relative] = sha256(path)

    isa = documents['isa_command']
    require(isa.get('request_protocol') == 'ready_valid'
            and isa.get('response_protocol') == 'ready_valid',
            'command request/response must use ready_valid')
    require(isa.get('completion_rule') == 'exactly_one_response_per_accepted_command',
            'one response per accepted command required')
    for field in ('command_order_owner', 'residency_tiling_owner', 'recovery_policy_owner'):
        require(isa.get(field) == 'ps_software', f'{field} must be ps_software')
    require(isa.get('pl_dispatcher_role') == 'route_execute_report_only',
            'dispatcher role must be route_execute_report_only')
    classes = isa.get('opcode_classes')
    require(isinstance(classes, dict) and set(classes) ==
            {'dma_load', 'dma_store', 'compute', 'control'}, 'exact opcode classes required')
    require(classes['dma_load'].get('canonical_opcode') == 'DMA_LOAD',
            'DMA_LOAD class mismatch')
    require(classes['dma_store'].get('canonical_opcode') == 'DMA_STORE',
            'DMA_STORE class mismatch')
    forbidden = set(classes['compute'].get('forbidden_operand_kinds', []))
    require({'external_ddr_address', 'local_raw_address', 'local_bank_base',
             'local_bank_offset'} <= forbidden, 'compute raw-address operands must be forbidden')
    require(classes['compute'].get('tensor_operand_kind') == 'local_bank_id',
            'compute tensor operands must be local bank IDs')

    bank = documents['local_bank']
    required = set(bank.get('descriptor_required_fields', []))
    require({'bank_id', 'capacity_words', 'word_bits', 'format', 'layout',
             'valid', 'busy', 'owner'} <= required, 'bank descriptor fields incomplete')
    rules = set(bank.get('ownership_rules', []))
    require('active_bank_cannot_be_overwritten' in rules,
            'active-bank overwrite rule required')
    require(bank.get('ownership_mode') == 'single_exclusive_module_port_role_per_bank',
            'bank ownership must use one exclusive module-port role per bank')
    require(bank.get('owner_semantics') == 'module_port_role_not_opcode_or_module_identity',
            'bank owner must identify a module port role')
    require('read_and_write_ownership_are_not_distinguished' in rules,
            'read/write ownership split is forbidden')
    require('command_bram_is_separate_from_data_banks' in rules,
            'command BRAM must be separate from the data-bank namespace')
    require('data_bank_zero_is_legal' in rules,
            'data bank zero must be a legal operand bank')
    require('operand_position_selects_the_module_port_role' in rules,
            'operand-position to module-port-role mapping is required')
    require('an_atomic_multi_bank_acquire_commits_all_requested_banks_or_none' in rules,
            'multi-bank acquire must be atomic')
    require('a_release_with_a_nonmatching_owner_port_does_not_clear_the_bank' in rules,
            'release owner matching is required')
    require('bank_zero_is_reserved_for_command_bram' not in rules,
            'data bank zero cannot be reserved for command BRAM')
    require(bank.get('compute_address_rule') ==
            'compute_never_receives_raw_local_address_or_offset',
            'bank contract must hide local addresses from compute')
    interface = bank.get('ownership_interface', {})
    require(interface.get('acquire') == ['acquire_valid', 'acquire_port']
            and interface.get('release') == ['release_valid', 'release_port']
            and interface.get('state') == ['bank_busy', 'bank_owner_port'],
            'bank ownership interface mismatch')
    require(bank.get('port_owner_ids') == {
        'NONE': 0, 'MM2S_ARBITER': 1, 'S2MM_ARBITER': 2,
        'GEMM_ACT': 3, 'GEMM_WGT': 4, 'GEMM_PSUM': 5},
        'port-owner ID namespace mismatch')
    require(bank.get('gemm_operand_role_mapping') == {
        'src0': 'GEMM_ACT', 'src1': 'GEMM_WGT', 'dst': 'GEMM_PSUM'},
        'GEMM operand-position role mapping mismatch')
    require(bank.get('gemm_alias_rule') ==
            'src0_src1_and_dst_must_name_three_distinct_banks',
            'GEMM bank alias rule mismatch')

    completion = documents['engine_completion']
    require(completion.get('completion_rule') ==
            'engine_resp_valid_only_after_all_reads_received_and_processed_and_all_writes_accepted',
            'engine completion must follow all read responses and accepted writes')
    require(completion.get('controller_rule') ==
            'matched_engine_completion_releases_tracked_roles_without_bank_read_pending',
            'controller must release from matched engine completion')
    require(completion.get('after_completion') ==
            'no_further_memory_requests_for_the_completed_command',
            'memory requests after completion are forbidden')
    require(completion.get('error_rule') ==
            'error_completion_requires_memory_quiescence_otherwise_retain_ownership_until_coordinated_reset',
            'error completion must preserve memory quiescence')

    evidence = documents['evidence_identity']
    require({'design_id', 'revision', 'source_sha256'} <=
            set(evidence.get('required_identity_fields', [])),
            'evidence identity fields incomplete')
    for value in inventory.values():
        require(re.fullmatch(r'[0-9a-f]{64}', value), 'invalid computed SHA-256')
    return {'status': 'passed_structure_only', 'contract_count': len(FILES),
            'contracts': inventory,
            'limitations': 'Common JSON declarations only; no model, RTL, tool, or board behavior proven.'}


if __name__ == '__main__':
    try:
        print(json.dumps(check(), indent=2))
    except (ContractError, OSError, TypeError) as error:
        print(json.dumps({'status': 'failed', 'error': str(error)}))
        raise SystemExit(1)
