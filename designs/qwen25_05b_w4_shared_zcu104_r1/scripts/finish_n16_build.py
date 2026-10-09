#!/usr/bin/env python3
"""Finish the immutable N16 board build and matched SD handoff, without board access."""
import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
BACKUP = Path('/media/admin1/backup/llm2rtl-builds') / BASE.name


def run(script, *args):
    print('START ' + script, flush=True)
    subprocess.run([sys.executable, str(BASE / 'scripts' / script)]
                   + [str(arg) for arg in args], check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--build', type=Path, default=BACKUP / 'board_200mhz_build_run009')
    args = parser.parse_args()
    build = args.build.resolve()
    last = 0
    while not (build / 'invocation.json').exists():
        if time.monotonic() - last >= 45:
            log = build / 'continuation_vivado.log'
            if not log.exists():
                log = build / 'vivado.log'
            lines = log.read_text(errors='replace').splitlines() if log.exists() else []
            print('WAIT ' + build.name + ': ' + (lines[-1] if lines else 'starting'), flush=True)
            last = time.monotonic()
        time.sleep(5)
    if json.loads((build / 'invocation.json').read_text())['returncode'] != 0:
        raise RuntimeError('N16 board build failed; no artifact publication')
    audit = BACKUP / 'board_200mhz_audit_run003'
    run('audit_board.py', build, audit)
    run('check_board_reset.py', build / 'qwen.hwh')
    bsp = BASE / 'releases/sd_bsp_run005'
    firmware = BASE / 'releases/baremetal_sd_run008'
    run('build_sd_bsp.py', build / 'qwen.xsa', bsp)
    run('build_baremetal.py', BACKUP / 'board_data_run003', firmware, '--sd-bsp', bsp)
    # Audit every linked instruction, including BSP and compiler helpers.
    instructions = []
    for line in (firmware / 'disassembly.txt').read_text().splitlines():
        match = re.match(r'\s*[0-9a-f]+:\s+[0-9a-f]{8}\s+(.*)', line)
        if match and re.search(r'\b(?:[bhsdqv][0-9]+)(?:\b|\.)', match.group(1)):
            instructions.append(line)
    if instructions:
        raise RuntimeError('Unexpected FP/SIMD instruction operands: ' + repr(instructions[:10]))
    fm = json.loads((firmware / 'manifest.json').read_text())
    runtime = {
        'status': 'passed_SD_firmware_integer_runtime_audit',
        'ELF_sha256': hashlib.sha256((firmware / 'qwen_baremetal.elf').read_bytes()).hexdigest(),
        'FP_or_SIMD_register_instructions': 0,
        'PS_runtime_scope': 'SD/FAT read, byte transfer, integer SHA256, ISA generation/control and byte output copies only',
        'physical_execution': False, 'SD_image': '0:/QWEN.BIN',
        'SD_load_gate': 'Full destination SHA256 and DSB precede compilation; loader failure returns before qwen_compile',
        'BSP_manifest': fm['BSP_manifest'],
    }
    (BASE / 'evidence/sd_runtime_audit_run008.json').write_text(json.dumps(runtime, indent=2) + '\n')
    handoff = BACKUP / 'board_handoff_200mhz_run004'
    run('package_handoff.py', '--build', build, '--audit', audit,
        '--data', BACKUP / 'board_data_run003', '--firmware', firmware, '--out', handoff)
    host = BASE / 'releases/qwen_host_sd_200mhz_run005'
    run('package_host.py', '--handoff', handoff, '--sd-firmware', firmware, '--out', host)
    subprocess.run([sys.executable, str(host / 'host.py'), 'verify'], check=True)
    patch = BASE / 'releases/qwen_sd_n16_patch_run002'
    old = BASE / 'releases/qwen_host_sd_200mhz_run003'
    run('package_host_patch.py', old, host, patch)
    run('validate_host_patch.py', old.with_suffix('.zip'), host.with_suffix('.zip'),
        patch.with_suffix('.zip'), BASE / 'evidence/n16_host_patch_validation_run002.json')
    report = {
        'status': 'prepared_native_N16_200MHz_SD_handoff_no_physical_acceptance',
        'build': str(build), 'audit': str(audit), 'firmware': str(firmware),
        'host': str(host), 'patch': str(patch), 'physical_board_model_pass': False,
    }
    (BASE / 'evidence/native_n16_handoff_run004.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
