#!/usr/bin/env python3
"""Evaluate frozen pilot candidates using unmodified official VerilogEval files."""
import csv
import hashlib
import json
import re
import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATASET = Path('/tmp/llm2rtl_verilogeval_20260930/dataset_spec-to-rtl')
TOOLS = Path('/home/shmin/nl2hdl/.conda_pkgs/iverilog-12.0-ha738cfc_1/bin')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(args, cwd, timeout):
    started = time.monotonic()
    try:
        result = subprocess.run(args, cwd=cwd, capture_output=True, text=True,
                                timeout=timeout)
        return {'command': args, 'returncode': result.returncode,
                'stdout': result.stdout, 'stderr': result.stderr,
                'seconds': time.monotonic() - started, 'timeout': False}
    except subprocess.TimeoutExpired as error:
        def decode(value):
            return value.decode(errors='replace') if isinstance(value, bytes) else value or ''
        return {'command': args, 'returncode': None,
                'stdout': decode(error.stdout), 'stderr': decode(error.stderr),
                'seconds': time.monotonic() - started, 'timeout': True}


def evaluate(source, dest, problem):
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, dest / 'candidate.sv')
    for suffix in ('_test.sv', '_ref.sv'):
        shutil.copy2(DATASET / (problem + suffix), dest / (problem + suffix))
    identities = {p.name: sha(p) for p in dest.glob('*.sv')}
    compile_result = command([str(TOOLS / 'iverilog'), '-Wall', '-Winfloop',
                              '-Wno-timescale', '-g2012', '-s', 'tb', '-o', 'sim.vvp',
                              'candidate.sv', problem + '_test.sv', problem + '_ref.sv'],
                             dest, 30)
    (dest / 'compile.log').write_text(compile_result['stdout'] + compile_result['stderr'])
    run = None
    if compile_result['timeout']:
        status = 'compile_timeout'
    elif compile_result['returncode'] != 0:
        status = 'compile_failure'
    else:
        run = command([str(TOOLS / 'vvp'), 'sim.vvp'], dest, 30)
        log = run['stdout'] + run['stderr']
        (dest / 'simulation.log').write_text(log)
        matches = re.findall(r'^Mismatches: (\d+) in (\d+) samples\s*$', log, re.MULTILINE)
        status = ('simulation_timeout' if run['timeout'] else
                  'simulation_error' if run['returncode'] != 0 else
                  'missing_result' if not matches else
                  'passed' if all(int(m) == 0 and int(n) > 0 for m, n in matches) else
                  'functional_failure')
    result = {'status': status, 'source_sha256': identities['candidate.sv'],
              'file_sha256': identities, 'compile': compile_result, 'simulation': run}
    (dest / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


def main():
    manifest = json.loads((ROOT / 'run_manifest.json').read_text())
    rows = []
    for task in manifest['problems']:
        problem = task['problem_id']
        worker = Path(task['directory'])
        result_file = ROOT / 'evaluation' / problem / 'problem_result.json'
        if result_file.exists():
            result = json.loads(result_file.read_text())
            if result.get('final_source_sha256') != sha(worker / 'candidate.sv'):
                raise RuntimeError(f'Frozen candidate changed after evaluation: {problem}')
        elif (worker / 'worker_report.json').exists() and (worker / 'candidate.sv').exists():
            report = json.loads((worker / 'worker_report.json').read_text())
            contract = json.loads((worker / 'contract.json').read_text())
            if contract.get('status') != 'frozen':
                raise RuntimeError(f'Unfrozen contract: {problem}')
            if report.get('contract_sha256', report.get('contract_hash')) != sha(worker / 'contract.json'):
                raise RuntimeError(f'Worker contract hash mismatch: {problem}')
            if report.get('final_source_sha256', report.get('final_source_hash')) != sha(worker / 'candidate.sv'):
                raise RuntimeError(f'Worker source hash mismatch: {problem}')
            if report.get('requested_model') != manifest['model']:
                raise RuntimeError(f'Worker model declaration mismatch: {problem}')
            if not 0 <= report.get('revision_count', -1) <= manifest['max_rtl_revisions']:
                raise RuntimeError(f'Worker revision budget violation: {problem}')
            final = evaluate(worker / 'candidate.sv', result_file.parent / 'final', problem)
            initial = (evaluate(worker / 'candidate_initial.sv', result_file.parent / 'initial', problem)
                       if (worker / 'candidate_initial.sv').exists() else None)
            result = {'problem_id': problem, 'status': final['status'],
                      'initial_status': initial['status'] if initial else 'unavailable',
                      'final_source_sha256': final['source_sha256'],
                      'contract_sha256': sha(worker / 'contract.json'),
                      'worker_report': report, 'final': final, 'initial': initial}
            result_file.write_text(json.dumps(result, indent=2) + '\n')
        else:
            result = {'problem_id': problem, 'status': 'generation_pending',
                      'initial_status': 'generation_pending', 'worker_report': {}}
        report = result['worker_report']
        rows.append({'problem_id': problem, 'status': result['status'],
                     'initial_status': result['initial_status'],
                     'elapsed_wall_seconds': report.get('elapsed_wall_seconds'),
                     'revision_count': report.get('revision_count'),
                     'token_usage': None})
    pending = sum(r['status'] == 'generation_pending' for r in rows)
    summary = {'benchmark': manifest['benchmark'], 'requested_model': manifest['model'],
               'dataset_commit': manifest['dataset_commit'], 'task_count': len(rows),
               'evaluated_count': len(rows) - pending, 'pending_count': pending,
               'passed_count': sum(r['status'] == 'passed' for r in rows),
               'initial_passed_count': sum(r['initial_status'] == 'passed' for r in rows),
               'pilot_final_success_rate': (sum(r['status'] == 'passed' for r in rows) / len(rows)
                                            if pending == 0 else None),
               'limitations': manifest['limitations'], 'problems': rows}
    (ROOT / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    with (ROOT / 'results.csv').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    manifest['status'] = 'completed' if pending == 0 else 'generation_in_progress'
    (ROOT / 'run_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({k: v for k, v in summary.items() if k != 'problems'}, indent=2))


if __name__ == '__main__':
    main()
