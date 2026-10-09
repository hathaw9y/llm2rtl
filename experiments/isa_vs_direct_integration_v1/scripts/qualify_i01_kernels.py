#!/usr/bin/env python3
"""Replay standalone kernels in a clean directory; never run existing tops."""
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

STUDY = Path(__file__).resolve().parents[1]
REPO = STUDY.parents[1]
DESIGN = REPO / 'designs/smollm2_135m_bf16_zcu104_r1'
VIVADO = Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    a.out.mkdir(parents=True, exist_ok=False)
    report = {'started_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
              'scope': 'Fresh standalone I01 kernel regression only. No integration, synthesis or board PASS.',
              'source_identity': [], 'fixture_identity': [], 'tests': []}
    for name in ['gemm_systolic_wide', 'rmsnorm', 'rope']:
        source = DESIGN / f'rtl/smollm2_{name}_executor.sv'
        target = a.out / source.name
        shutil.copyfile(source, target)
        report['source_identity'].append({'file': source.name, 'sha256': sha(target)})
    for name in ['rmsnorm_executor', 'rmsnorm_golden', 'rope_executor', 'gemm_systolic_wide_executor']:
        source = DESIGN / f'tb/tb_smollm2_{name}.sv'
        shutil.copyfile(source, a.out / source.name)
        report['fixture_identity'].append({'file': source.name, 'sha256': sha(source)})

    def run(label, command, marker=None, timeout=600):
        start = time.monotonic()
        log = a.out / (label + '.log')
        with log.open('w') as stream:
            try:
                result = subprocess.run([str(x) for x in command], cwd=a.out,
                                        stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
                code = result.returncode
            except subprocess.TimeoutExpired:
                code = None
        output = log.read_text(errors='replace')
        entry = {'label': label, 'command': [str(x) for x in command],
                 'exit_code': code, 'elapsed_seconds': time.monotonic() - start,
                 'log_sha256': sha(log), 'passed': code == 0 and (marker is None or marker in output)}
        report['tests'].append(entry)
        (a.out / 'qualification.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(entry), flush=True)
        if not entry['passed']:
            raise RuntimeError(f'{label} failed; inspect {log}')

    def fixture_tree(relative):
        source = DESIGN / relative
        target = a.out / relative
        shutil.copytree(source, target)
        for path in sorted(target.rglob('*')):
            if path.is_file():
                report['fixture_identity'].append({'file': str(path.relative_to(a.out)), 'sha256': sha(path)})
        return target

    try:
        run('rms_control_compile', ['iverilog', '-g2012', '-s', 'tb_smollm2_rmsnorm_executor', '-o',
             'rms_control.vvp', 'smollm2_rmsnorm_executor.sv', 'tb_smollm2_rmsnorm_executor.sv'])
        run('rms_control', ['vvp', 'rms_control.vvp'], 'RMSNORM EXECUTOR PASS')
        run('rms_golden_compile', ['iverilog', '-g2012', '-s', 'tb_smollm2_rmsnorm_golden', '-o',
             'rms_golden.vvp', 'smollm2_rmsnorm_executor.sv', 'tb_smollm2_rmsnorm_golden.sv'])
        for label, relative, flags in [
            ('random', 'golden/rmsnorm', []),
            ('prefill', 'golden/rmsnorm_checkpoint/prefill', []),
            ('decode', 'golden/rmsnorm_checkpoint/decode', ['+ONLY_ONE_ROW']),
            ('large', 'golden/rmsnorm_checkpoint/large_input', [])]:
            directory = fixture_tree(relative)
            run('rms_' + label, ['vvp', 'rms_golden.vvp', '+VECTOR_DIR=' + str(directory), *flags], 'PASS')
        run('rope_compile', ['iverilog', '-g2012', '-s', 'tb_smollm2_rope_executor', '-o',
             'rope.vvp', 'smollm2_rope_executor.sv', 'tb_smollm2_rope_executor.sv'])
        for label, rows in [('prefill', 32), ('decode', 1), ('prefill_tail', 32)]:
            directory = fixture_tree('golden/rope_checkpoint/' + label)
            for kind in ['q', 'k']:
                run(f'rope_{label}_{kind}', ['vvp', 'rope.vvp', '+CASE=' + str(directory),
                    '+KIND=' + kind, '+ROWS=' + str(rows)], 'PASS')
        directory = a.out / 'golden/rope_checkpoint/decode'
        for invalid in ['zero_rows', 'too_many_rows', 'wrong_bank', 'nan_input']:
            run('rope_error_' + invalid, ['vvp', 'rope.vvp', '+CASE=' + str(directory),
                '+KIND=q', '+ROWS=1', '+NEGATIVE=' + invalid], 'PASS')
        for relative in ['golden/gemm_executor', 'golden/gemm_model', 'golden/gemm_systolic_model']:
            directory = fixture_tree(relative)
            for file in directory.glob('*.hex'):
                shutil.copyfile(file, a.out / file.name)
        run('gemm_compile', [VIVADO / 'xvlog', '-sv', 'smollm2_gemm_systolic_wide_executor.sv',
                             'tb_smollm2_gemm_systolic_wide_executor.sv'])
        run('gemm_elaborate', [VIVADO / 'xelab', 'tb_smollm2_gemm_systolic_wide_executor',
                             '--timescale', '1ns/1ps', '-s', 'gemm_sim'])
        run('gemm_simulate', [sys.executable, REPO / 'ip/infrastructure/datamover_engine/scripts/run_xsimk.py',
                             a.out / 'xsim.dir/gemm_sim/xsimk', 'PASS smollm2_gemm_systolic_wide_executor'],
                             'PASS smollm2_gemm_systolic_wide_executor')
        report['status'] = 'PASS'
    except Exception as exc:
        report['status'] = 'FAIL'
        report['error'] = repr(exc)
        raise
    finally:
        report['ended_utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
        (a.out / 'qualification.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
