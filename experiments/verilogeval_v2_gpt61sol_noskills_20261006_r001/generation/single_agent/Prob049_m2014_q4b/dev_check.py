#!/usr/bin/env python3
"""Fixed development evaluator. Contains no official benchmark information."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import time
from pathlib import Path

IV = Path('/home/shmin/nl2hdl/.conda_pkgs/iverilog-12.0-ha738cfc_1/bin/iverilog')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args, directory):
    start = time.monotonic()
    try:
        p = subprocess.run(args, cwd=directory, capture_output=True, text=True, timeout=30)
        return {'command': args, 'returncode': p.returncode, 'stdout': p.stdout,
                'stderr': p.stderr, 'timeout': False, 'seconds': time.monotonic()-start}
    except subprocess.TimeoutExpired as e:
        decode = lambda s: s.decode(errors='replace') if isinstance(s, bytes) else s or ''
        return {'command': args, 'returncode': None, 'stdout': decode(e.stdout),
                'stderr': decode(e.stderr), 'timeout': True, 'seconds': time.monotonic()-start}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    root = Path.cwd()
    assert (root/'candidate.sv').exists() and (root/'dev_tb.sv').exists()
    history = root/'dev_checks.jsonl'
    prior = [json.loads(line) for line in history.read_text().splitlines()] if history.exists() else []
    if not prior:
        initial = root/'candidate_initial.sv'
        if initial.exists():
            assert sha(initial) == sha(root/'candidate.sv'), 'Initial snapshot differs before first check'
        else:
            shutil.copy2(root/'candidate.sv', initial)
    count = len(prior)+1
    directory = root/'development'/f'{count:02d}'
    directory.mkdir(parents=True, exist_ok=False)
    for name in ('candidate.sv', 'dev_tb.sv'):
        shutil.copy2(root/name, directory/name)
    result = {'label': args.label, 'check_index': count, 'checked_at_unix': time.time(),
              'source_sha256': sha(directory/'candidate.sv'),
              'testbench_sha256': sha(directory/'dev_tb.sv'), 'directory': str(directory)}
    compile_result = run([str(IV), '-g2012', '-Wall', '-Wno-timescale', '-s', 'dev_tb',
                          '-o', 'dev.vvp', 'candidate.sv', 'dev_tb.sv'], directory)
    result['compile'] = compile_result
    (directory/'compile.log').write_text(compile_result['stdout']+compile_result['stderr'])
    if compile_result['returncode'] == 0 and not compile_result['timeout']:
        simulation = run([str(IV.with_name('vvp')), 'dev.vvp'], directory)
        result['simulation'] = simulation
        log = simulation['stdout']+simulation['stderr']
        (directory/'simulation.log').write_text(log)
        passed = (simulation['returncode'] == 0 and not simulation['timeout']
                  and bool(re.search(r'^PASS\b', log, re.M))
                  and not re.search(r'^FAIL\b|^FATAL\b', log, re.M))
        result['status'] = 'passed' if passed else 'simulation_failed'
    else:
        result['simulation'] = None
        result['status'] = 'compile_timeout' if compile_result['timeout'] else 'compile_failed'
        if compile_result['returncode'] in (139, -11) and Path('/usr/bin/iverilog').exists():
            diagnostic = run(['/usr/bin/iverilog', '-g2012', '-Wall', '-Wno-timescale',
                              '-s', 'dev_tb', '-o', 'diagnostic.vvp', 'candidate.sv', 'dev_tb.sv'], directory)
            result['supplemental_v11_diagnostic'] = diagnostic
            (directory/'supplemental_v11.log').write_text(diagnostic['stdout']+diagnostic['stderr'])
    (directory/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    with history.open('a') as stream:
        stream.write(json.dumps(result)+'\n')
    (root/'dev_final_result.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['status'] == 'passed' else 1)


if __name__ == '__main__':
    main()
