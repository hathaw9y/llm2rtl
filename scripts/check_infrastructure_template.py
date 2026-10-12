#!/usr/bin/env python3
"""Fail-closed identity and structure gate for the command dispatcher template."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
INDEX = Path('ip/infrastructure/contracts/controller_index.json')
LEGACY_INDEX = Path('ip/infrastructure/cmd_dispatcher_template/template_index.json')


class TemplateError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise TemplateError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, f'duplicate JSON key: {path}: {key}')
            result[key] = value
        return result
    try:
        return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique)
    except (UnicodeError, json.JSONDecodeError) as error:
        raise TemplateError(f'invalid JSON: {path}: {error}') from error


def check(root=ROOT, expected_index_sha256=None, require_rtl=True):
    root = Path(root).resolve()
    index_path = root / (INDEX if (root / INDEX).exists() else LEGACY_INDEX)
    require(index_path.is_file() and not index_path.is_symlink(), 'missing template index')
    index_hash = digest(index_path)
    if expected_index_sha256 is not None:
        require(index_hash == expected_index_sha256, 'template index SHA-256 mismatch')
    index = read_json(index_path)
    require(index.get('schema') == 'llm2rtl.infrastructure_template_index.v1',
            'unsupported template index schema')
    require(index.get('template_id') == 'cmd_dispatcher_template', 'template ID mismatch')
    require(index.get('status') == 'frozen', 'template index is not frozen')

    identities = {index['contract']['path']: index['contract']['sha256']}
    identities.update(index.get('common_contracts', {}))
    native_reference = index.get('native_bank_contract')
    if native_reference is not None:
        identities[native_reference['path']] = native_reference['sha256']
    for relative, expected in identities.items():
        path = root / relative
        require(path.is_file() and not path.is_symlink(), f'missing pinned input: {relative}')
        require(re.fullmatch(r'[0-9a-f]{64}', expected or '') is not None,
                f'invalid pinned SHA-256: {relative}')
        require(digest(path) == expected, f'pinned input SHA-256 mismatch: {relative}')

    contract = read_json(root / index['contract']['path'])
    fixed = contract.get('fixed_architecture', {})
    require(contract.get('status') == 'frozen_for_implementation', 'contract is not frozen')
    require(fixed.get('command_bram_is_not_a_data_bank') is True,
            'command BRAM must be separate from data banks')
    require(fixed.get('data_bank_indices') == '0 through BANK_NUM-1',
            'data bank zero must remain legal')
    require(fixed.get('fixed_opcodes') == {'END': 0, 'MM2S': 1, 'S2MM': 2},
            'fixed opcode set mismatch')
    ownership = contract.get('fixed_ports', {}).get('bank_ownership', [])
    directional = contract.get('version') in (3, 4)
    if directional:
        require(native_reference == contract.get('native_bank_contract'),
                'native bank contract reference mismatch')
        require(native_reference is not None,
                'directional controller requires a pinned native bank contract')
        require(fixed.get('port_owner_ids') == {
            'NONE': 0, 'MM2S_ARBITER': 1, 'S2MM_ARBITER': 2},
            'shared controller must fix only DMA roles')
        expected_ownership = [
            f'bank_{direction}_{field}[BANK_NUM-1:0]' +
            ('[PORT_ROLE_WIDTH-1:0]' if field.endswith('_port') else '')
            for direction in ('wr', 'rd')
            for field in ('acquire_valid', 'acquire_port', 'release_valid',
                          'release_port', 'busy', 'owner_port',
                          'acquire_accepted', 'release_accepted')
        ] + (['bank_rd_pending[BANK_NUM-1:0]'] if contract['version'] == 3 else []) + ['bank_subsystem_error']
        if contract['version'] == 4:
            completion = contract.get('engine_completion_contract', {})
            require(completion.get('path') == 'contracts/common/engine_completion_contract.json'
                    and identities.get(completion['path']) == completion.get('sha256'),
                    'engine completion contract must be pinned')
    else:
        require(contract.get('version') == 2, 'unsupported template version')
        expected_ownership = [
        'bank_acquire_valid[0:BANK_NUM-1]',
        'bank_acquire_port[0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0]',
        'bank_release_valid[0:BANK_NUM-1]',
        'bank_release_port[0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0]',
        'bank_busy[0:BANK_NUM-1]',
        'bank_owner_port[0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0]']
    require(ownership == expected_ownership,
        'module-port ownership interface mismatch')

    result = {'status': 'passed_contract_identity', 'index_sha256': index_hash,
              'scope': 'compatibility_family_only_not_default_design_reference',
              'checked_inputs': identities}
    if not require_rtl:
        return result

    rtl_path = root / index['implementation_path']
    require(rtl_path.is_file() and not rtl_path.is_symlink(), 'missing template RTL')
    rtl = rtl_path.read_text(encoding='utf-8')
    require(re.search(r'\bmodule\s+cmd_dispatcher_template\b', rtl) is not None,
            'template top module missing')
    for parameter in contract.get('parameters', []):
        require(re.search(rf'\bparameter\b[^;)]*\b{re.escape(parameter)}\b', rtl, re.S),
                f'missing parameter: {parameter}')
    fixed_names = ('cmd_enb', 'cmd_addrb', 'cmd_doutb',
                   'm_ctrl_mm2s_cmd_valid', 'm_ctrl_s2mm_cmd_valid')
    ownership_names = tuple(port.split('[')[0] for port in expected_ownership)
    for port in fixed_names + ownership_names:
        require(re.search(rf'\b{port}\b', rtl), f'missing fixed port: {port}')
    if directional:
        require('[BANK_NUM-1:0]' in rtl,
                'native bank ownership ports must use [BANK_NUM-1:0]')
        for obsolete in ('bank_acquire_valid', 'bank_release_valid', 'bank_busy') + (
                ('bank_rd_pending',) if contract['version'] == 4 else ()):
            require(re.search(rf'\b{obsolete}\b', rtl) is None,
                    f'obsolete exclusive ownership port: {obsolete}')
        for state in ('CMD_READ', 'CMD_WAIT', 'OP_VERIFY', 'BANK_ACQUIRE', 'EXECUTE'):
            require(re.search(rf'\b{state}\b', rtl),
                    f'missing controller state: {state}')
    else:
        require('[0:BANK_NUM-1]' in rtl, 'bank ownership ports must use [0:BANK_NUM-1]')
        for forbidden in ('bank_rd_acquire', 'bank_wr_acquire', 'bank_rd_release',
                      'bank_wr_release', 'bank_rd_busy', 'bank_wr_busy'):
            require(forbidden not in rtl, f'forbidden read/write ownership split: {forbidden}')
    require(re.search(r'\bs_axi_[A-Za-z0-9_]*', rtl) is None,
            'template must not expose an AXI BRAM Controller slave interface')
    markers = contract.get('required_user_markers', [])
    positions = []
    for marker in markers:
        require(rtl.count(marker) == 1, f'USER marker must occur exactly once: {marker}')
        positions.append(rtl.index(marker))
    require(positions == sorted(positions), 'USER markers are not in contract order')
    extension_hooks = (
        'user_opcode_known_w', 'user_command_legal_w', 'user_bank_eligible_w',
        'user_request_valid_w', 'user_request_ready_w', 'user_request_fire_w',
        'user_bank_acquire_valid_w', 'user_bank_acquire_port_w',
        'user_bank_release_valid_w', 'user_bank_release_port_w', 'user_pending_any_w',
        'user_response_fault_w', 'user_executor_fault_w',
    )
    if directional:
        extension_hooks = tuple(hook for hook in extension_hooks
                                if not hook.startswith('user_bank_'))
        extension_hooks += tuple(
            f'user_bank_{direction}_{operation}_{field}_w'
            for direction in ('wr', 'rd')
            for operation in ('acquire', 'release')
            for field in ('valid', 'port'))
    for hook in extension_hooks:
        require(re.search(rf'\b{hook}\b', rtl), f'missing executable USER hook: {hook}')
    result.update(status='passed_rtl_structure', rtl_sha256=digest(rtl_path))
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--expected-index-sha256')
    parser.add_argument('--contract-only', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps(check(args.root, args.expected_index_sha256,
                               require_rtl=not args.contract_only), indent=2))
    except (TemplateError, KeyError, OSError, TypeError) as error:
        print(json.dumps({'status': 'failed', 'error': str(error)}))
        raise SystemExit(1)


if __name__ == '__main__':
    main()
