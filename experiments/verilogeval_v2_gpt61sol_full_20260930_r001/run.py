#!/usr/bin/env python3
"""Resumeable paired full-set experiment with fresh Codex sessions per job."""
import argparse
import concurrent.futures
import csv
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATASET = Path('/tmp/llm2rtl_verilogeval_20260930/dataset_spec-to-rtl')
TOOLS = Path('/home/shmin/nl2hdl/.conda_pkgs/iverilog-12.0-ha738cfc_1/bin')
STOP = threading.Event()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, data):
    tmp = path.with_suffix(path.suffix + '.tmp')
    tmp.write_text(json.dumps(data, indent=2) + '\n')
    tmp.replace(path)


def checked(args, cwd, timeout):
    begin = time.monotonic()
    try:
        p = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return {'command': args, 'returncode': p.returncode, 'stdout': p.stdout,
                'stderr': p.stderr, 'timeout': False, 'seconds': time.monotonic() - begin}
    except subprocess.TimeoutExpired as e:
        decode = lambda x: x.decode(errors='replace') if isinstance(x, bytes) else x or ''
        return {'command': args, 'returncode': None, 'stdout': decode(e.stdout),
                'stderr': decode(e.stderr), 'timeout': True, 'seconds': time.monotonic() - begin}


def evaluate(source, dest, problem):
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, dest / 'candidate.sv')
    for suffix in ('_test.sv', '_ref.sv'):
        shutil.copy2(DATASET / (problem + suffix), dest / (problem + suffix))
    hashes = {p.name: sha(p) for p in dest.glob('*.sv')}
    compile_result = checked([str(TOOLS / 'iverilog'), '-Wall', '-Winfloop',
                              '-Wno-timescale', '-g2012', '-s', 'tb', '-o', 'sim.vvp',
                              'candidate.sv', problem + '_test.sv', problem + '_ref.sv'], dest, 30)
    (dest / 'compile.log').write_text(compile_result['stdout'] + compile_result['stderr'])
    run = None
    if compile_result['timeout']:
        status = 'compile_timeout'
    elif compile_result['returncode'] != 0:
        status = 'compile_failure'
    else:
        run = checked([str(TOOLS / 'vvp'), 'sim.vvp'], dest, 30)
        log = run['stdout'] + run['stderr']
        (dest / 'simulation.log').write_text(log)
        matches = re.findall(r'^Mismatches: (\d+) in (\d+) samples\s*$', log, re.MULTILINE)
        status = ('simulation_timeout' if run['timeout'] else
                  'simulation_error' if run['returncode'] != 0 else
                  'missing_result' if not matches else
                  'passed' if all(int(m) == 0 and int(n) > 0 for m, n in matches) else
                  'functional_failure')
    result = {'status': status, 'file_sha256': hashes,
              'compile': compile_result, 'simulation': run}
    save(dest / 'result.json', result)
    return result


def usage_from(path):
    usage = None
    errors = []
    for line in path.read_text(errors='replace').splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get('type') == 'turn.completed':
            usage = event.get('usage')
        if event.get('type') in ('turn.failed', 'error'):
            errors.append(event)
    return usage, errors


def work(job, manifest):
    mode, name = job['mode'], job['problem_id']
    d = Path(job['directory'])
    result_path = d / 'run_result.json'
    if result_path.exists():
        prior = json.loads(result_path.read_text())
        if prior.get('final_source_sha256') and prior['final_source_sha256'] != sha(d / 'candidate.sv'):
            raise RuntimeError(f'Evaluated candidate changed: {mode}/{name}')
        return prior
    if STOP.is_set():
        return None
    if sha(d / 'problem.txt') != manifest['prompt_sha256'][name]:
        raise RuntimeError(f'Prompt changed: {mode}/{name}')
    if sha(d / 'policy.txt') != manifest['policy_sha256'][mode]:
        raise RuntimeError(f'Policy changed: {mode}/{name}')
    if (d / 'generation_record.json').exists():
        generation = json.loads((d / 'generation_record.json').read_text())
    else:
        if (d / 'started.json').exists():
            raise RuntimeError(f'Interrupted generation needs explicit audit before retry: {mode}/{name}')
        if mode == 'contract_based':
            shutil.copy2(ROOT / 'validate_contract.py', d / 'validate_contract.py')
        args = ['codex', 'exec', '--ignore-user-config', '--ephemeral',
                '--skip-git-repo-check', '--sandbox', 'workspace-write',
                '--model', manifest['model'], '-c', 'features.multi_agent=false',
                '-c', 'web_search="disabled"', '--json', '-C', str(d),
                '--output-last-message', str(d / 'final_message.txt'), '-']
        prompt = (d / 'policy.txt').read_text() + '\nORIGINAL PROBLEM:\n' + (d / 'problem.txt').read_text()
        start = time.time()
        save(d / 'started.json', {'started_at_unix': start, 'command': args,
                                 'prompt_sha256': hashlib.sha256(prompt.encode()).hexdigest()})
        with (d / 'events.jsonl').open('w') as out, (d / 'cli_stderr.log').open('w') as err:
            p = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=out, stderr=err,
                                 cwd=d, text=True, start_new_session=True)
            timeout = False
            try:
                p.communicate(prompt, timeout=manifest['generation_timeout_seconds'])
            except subprocess.TimeoutExpired:
                timeout = True
                os.killpg(p.pid, signal.SIGTERM)
                try:
                    p.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(p.pid, signal.SIGKILL)
                    p.wait()
        usage, errors = usage_from(d / 'events.jsonl')
        generation = {'command': args, 'started_at_unix': start, 'ended_at_unix': time.time(),
                      'seconds': time.time() - start, 'returncode': p.returncode,
                      'timeout': timeout, 'usage': usage, 'cli_errors': errors}
        save(d / 'generation_record.json', generation)
        if errors and not (d / 'candidate.sv').exists() and not timeout:
            STOP.set()
            raise RuntimeError(f'CLI infrastructure failure: {mode}/{name}; inspect events.jsonl')
    final = initial = None
    issues = []
    if generation['timeout']:
        issues.append('generation_timeout')
    if generation['returncode'] != 0:
        issues.append('generation_exit_failure')
    report = {}
    if (d / 'worker_report.json').exists():
        try:
            report = json.loads((d / 'worker_report.json').read_text())
        except json.JSONDecodeError:
            issues.append('invalid_worker_report')
    else:
        issues.append('missing_worker_report')
    revisions = report.get('revision_count')
    if not isinstance(revisions, int) or not 0 <= revisions <= manifest['max_rtl_revisions']:
        issues.append('invalid_revision_count')
    if mode == 'contract_based':
        try:
            contract = json.loads((d / 'contract.json').read_text())
            gate = json.loads((d / 'contract_gate.json').read_text())
            history = [json.loads(x) for x in (d / 'contract_gate_history.jsonl').read_text().splitlines()]
            assert contract.get('status') == 'frozen'
            for f in ('interface', 'semantics', 'numeric', 'verification'):
                assert isinstance(contract.get(f), dict) and contract[f]
            assert isinstance(contract.get('specification_ambiguities'), list)
            assert gate['status'] == 'passed_structure_only'
            assert gate['contract_sha256'] == sha(d / 'contract.json')
            assert history[0]['checked_at_unix'] <= (d / 'candidate_initial.sv').stat().st_mtime
        except (OSError, ValueError, AssertionError, KeyError, IndexError, TypeError):
            issues.append('contract_gate_failure')
    elif (d / 'contract.json').exists() or (d / 'contract_gate.json').exists():
        issues.append('baseline_created_contract')
    if (d / 'candidate.sv').exists():
        final = evaluate(d / 'candidate.sv', ROOT / 'evaluation' / mode / name / 'final', name)
    else:
        issues.append('missing_candidate')
    if (d / 'candidate_initial.sv').exists():
        initial = evaluate(d / 'candidate_initial.sv', ROOT / 'evaluation' / mode / name / 'initial', name)
    else:
        issues.append('missing_initial_candidate')
    status = final['status'] if final else 'generation_failure'
    result = {'mode': mode, 'problem_id': name, 'official_status': status,
              'workflow_status': 'passed' if status == 'passed' and not issues else 'failed',
              'protocol_issues': issues, 'generation': generation, 'revision_count': revisions,
              'final_source_sha256': sha(d / 'candidate.sv') if final else None,
              'contract_sha256': sha(d / 'contract.json') if (d / 'contract.json').exists() else None,
              'worker_report': report, 'final': final, 'initial': initial}
    save(result_path, result)
    return result


def summarize(manifest):
    rows, results = [], []
    validity_path = ROOT / 'benchmark_validity.json'
    invalid = (set(json.loads(validity_path.read_text())['invalid_problems'])
               if validity_path.exists() else set())
    for job in manifest['jobs']:
        p = Path(job['directory']) / 'run_result.json'
        if not p.exists():
            continue
        r = json.loads(p.read_text())
        results.append(r)
        usage = r['generation'].get('usage') or {}
        rows.append({'mode': r['mode'], 'problem_id': r['problem_id'],
                     'official_status': r['official_status'], 'workflow_status': r['workflow_status'],
                     'official_analyzer_code': r.get('official_analyzer_code'),
                     'reference_valid': r['problem_id'] not in invalid,
                     'protocol_issues': ';'.join(r['protocol_issues']),
                     'initial_status': r['initial']['status'] if r['initial'] else 'unavailable',
                     'generation_seconds': r['generation']['seconds'],
                     'revision_count': r['revision_count'], 'input_tokens': usage.get('input_tokens'),
                     'cached_input_tokens': usage.get('cached_input_tokens'),
                     'output_tokens': usage.get('output_tokens'),
                     'reasoning_output_tokens': usage.get('reasoning_output_tokens')})
    summary = {'benchmark': manifest['benchmark'], 'model': manifest['model'],
               'dataset_commit': manifest['dataset_commit'], 'completed_jobs': len(rows),
               'total_jobs': len(manifest['jobs']), 'conditions': {}}
    for mode in manifest['conditions']:
        selected = [r for r in rows if r['mode'] == mode]
        completed = len(selected)
        summary['conditions'][mode] = {
            'completed': completed, 'total': manifest['task_count_per_arm'],
            'official_passed': sum(r['official_status'] == 'passed' for r in selected),
            'workflow_passed': sum(r['workflow_status'] == 'passed' for r in selected),
            'initial_passed': sum(r['initial_status'] == 'passed' for r in selected),
            'official_pass_at_1': (sum(r['official_status'] == 'passed' for r in selected) / completed
                                   if completed == manifest['task_count_per_arm'] else None),
            'workflow_success_rate': (sum(r['workflow_status'] == 'passed' for r in selected) / completed
                                      if completed == manifest['task_count_per_arm'] else None),
            'generation_seconds_total': sum(r['generation_seconds'] for r in selected),
            'input_tokens_total': sum(r['input_tokens'] or 0 for r in selected),
            'output_tokens_total': sum(r['output_tokens'] or 0 for r in selected)}
    paired = {}
    for name in manifest['problems']:
        pair = {r['mode']: r for r in rows if r['problem_id'] == name}
        if len(pair) == 2:
            a = pair['single_agent']['official_status'] == 'passed'
            b = pair['contract_based']['official_status'] == 'passed'
            key = 'both_pass' if a and b else 'single_only' if a else 'contract_only' if b else 'both_fail'
            paired.setdefault(key, []).append(name)
    summary['paired_outcomes'] = paired
    summary['limitations'] = manifest['limitations']
    save(ROOT / 'summary.json', summary)
    if rows:
        with (ROOT / 'results.csv').open('w', newline='') as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(sorted(rows, key=lambda r: (r['problem_id'], r['mode'])))
    return summary


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--workers', type=int, default=3)
    parser.add_argument('--limit', type=int)
    parser.add_argument('--summary-only', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((ROOT / 'run_manifest.json').read_text())
    if args.summary_only:
        print(json.dumps(summarize(manifest), indent=2))
        return
    assert 1 <= args.workers <= 3
    actual = checked(['git', '-C', str(DATASET.parent), 'rev-parse', 'HEAD'], ROOT, 10)
    assert actual['returncode'] == 0 and actual['stdout'].strip() == manifest['dataset_commit']
    manifest['status'] = 'running'
    save(ROOT / 'run_manifest.json', manifest)
    jobs = [j for j in manifest['jobs'] if not (Path(j['directory']) / 'run_result.json').exists()]
    if args.limit is not None:
        jobs = jobs[:args.limit]
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = {pool.submit(work, j, manifest): j for j in jobs}
            for future in concurrent.futures.as_completed(futures):
                result = future.result()
                if result:
                    summary = summarize(manifest)
                    print(f"{summary['completed_jobs']}/312 {result['mode']} {result['problem_id']} "
                          f"official={result['official_status']} protocol={result['protocol_issues']}", flush=True)
        summary = summarize(manifest)
        manifest['status'] = 'completed' if summary['completed_jobs'] == len(manifest['jobs']) else 'partial'
    except Exception as error:
        STOP.set()
        manifest['status'] = 'infrastructure_error'
        manifest['error'] = str(error)
        summarize(manifest)
        raise
    finally:
        save(ROOT / 'run_manifest.json', manifest)


if __name__ == '__main__':
    main()
