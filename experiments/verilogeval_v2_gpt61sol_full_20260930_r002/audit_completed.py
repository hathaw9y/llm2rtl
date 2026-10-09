#!/usr/bin/env python3
"""Post-run integrity/coverage audit; never changes candidate sources."""
import collections
import csv
import datetime
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATASET = Path('/tmp/llm2rtl_verilogeval_20260930/dataset_spec-to-rtl')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    manifest = json.loads((ROOT/'run_manifest.json').read_text())
    provenance = json.loads((ROOT/'provenance/provenance.json').read_text())
    issues = []
    checks = 0
    commands = 0
    counts = collections.Counter()
    for name, expected in provenance['script_sha256'].items():
        if sha(ROOT/name) != expected:
            issues.append('runner/helper source changed: '+name)
    for name, expected in provenance['skill_sha256'].items():
        if sha(Path(name)) != expected:
            issues.append('permitted skill source changed: '+name)
    for job in manifest['jobs']:
        d = Path(job['directory'])
        mode, name = job['mode'], job['problem_id']
        result = json.loads((d/'run_result.json').read_text())
        counts[mode] += 1
        checks_to_make = [(d/'problem.txt', manifest['prompt_sha256'][name]),
                          (d/'policy.txt', manifest['policy_sha256'][mode]),
                          (d/'candidate.sv', result['final_source_sha256'])]
        checks_to_make.extend((d/n, h) for n, h in manifest['helper_sha256'].items())
        for path, expected in checks_to_make:
            checks += 1
            if sha(path) != expected:
                issues.append('hash mismatch: '+str(path))
        for which in ('initial', 'final'):
            directory = ROOT/'evaluation'/mode/name/which
            for file, expected in result[which]['file_sha256'].items():
                checks += 1
                if sha(directory/file) != expected:
                    issues.append('evaluation snapshot hash: '+str(directory/file))
                if file != 'candidate.sv' and sha(directory/file) != sha(DATASET/file):
                    issues.append('official source changed: '+str(directory/file))
            source = d/('candidate_initial.sv' if which == 'initial' else 'candidate.sv')
            if sha(source) != sha(directory/'candidate.sv'):
                issues.append('evaluated source differs: '+str(source))
        history = [json.loads(line) for line in (d/'dev_checks.jsonl').read_text().splitlines()]
        if history[0]['source_sha256'] != sha(d/'candidate_initial.sv'):
            issues.append('initial development identity: '+name)
        if history[-1]['source_sha256'] != sha(d/'candidate.sv'):
            issues.append('final development identity: '+name)
        if history[-1]['testbench_sha256'] != sha(d/'dev_tb.sv'):
            issues.append('final TB identity: '+name)
        for record in history:
            directory = Path(record['directory'])
            for file, key in [('candidate.sv', 'source_sha256'), ('dev_tb.sv', 'testbench_sha256')]:
                checks += 1
                if sha(directory/file) != record[key]:
                    issues.append('development snapshot changed: '+str(directory/file))
            if json.loads((directory/'result.json').read_text()) != record:
                issues.append('development history differs: '+str(directory))
        if history[-1]['status'] != 'passed' or not history[-1].get('simulation'):
            issues.append('final development not dynamically passed: '+name)
        if json.loads((d/'environment_smoke.json').read_text())['status'] != 'passed':
            issues.append('environment smoke: '+name)
        if mode == 'contract_based':
            gate = json.loads((d/'contract_gate.json').read_text())
            gates = [json.loads(line) for line in (d/'contract_gate_history.jsonl').read_text().splitlines()]
            if sha(d/'contract.json') != gate['contract_sha256'] or result['contract_sha256'] != gate['contract_sha256']:
                issues.append('contract identity: '+name)
            if gates[0]['checked_at_unix'] > (d/'candidate_initial.sv').stat().st_mtime:
                issues.append('contract after initial RTL: '+name)
        if result['protocol_issues']:
            issues.append({'protocol': mode+'/'+name, 'issues': result['protocol_issues']})
        for line in (d/'events.jsonl').read_text().splitlines():
            event = json.loads(line)
            item = event.get('item') or {}
            if event.get('type') == 'item.started' and item.get('type') == 'command_execution':
                commands += 1
                command = item.get('command', '')
                if re.search(r'llm2rtl_verilogeval|dataset_spec-to-rtl|_ref\.sv|_test\.sv|/evaluation/|/experiments/|verilogeval_v2_gpt61sol_pilot', command):
                    # This run's own working path may be supplied to tool commands.
                    stripped = command.replace(str(d), 'CURRENT_TASK')
                    if re.search(r'llm2rtl_verilogeval|dataset_spec-to-rtl|_ref\.sv|_test\.sv|/evaluation/|/experiments/|verilogeval_v2_gpt61sol_pilot', stripped):
                        issues.append({'possible_forbidden_access': mode+'/'+name, 'command': command})
    rows = list(csv.DictReader((ROOT/'results.csv').open()))
    final = json.loads((ROOT/'final_comparison.json').read_text())
    summary = json.loads((ROOT/'summary.json').read_text())
    if len(rows) != 312 or dict(counts) != {'single_agent': 156, 'contract_based': 156}:
        issues.append('coverage differs from 156x2')
    for mode in counts:
        passed = sum(row['mode'] == mode and row['official_status'] == 'passed' for row in rows)
        if passed != final['conditions'][mode]['official_passed_all_156'] or passed != summary['conditions'][mode]['official_passed']:
            issues.append('aggregation disagreement: '+mode)
    report = {'status': 'passed' if not issues else 'review_required',
              'audited_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'jobs_per_condition': dict(counts), 'csv_rows': len(rows),
              'file_hash_checks': checks, 'executed_commands_scanned': commands,
              'forbidden_access_scan_scope': 'Heuristic command scan; not hard filesystem isolation',
              'issues': issues}
    (ROOT/'completion_audit.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))
    if issues:
        raise SystemExit(1)
    manifest['completed_utc'] = report['audited_at_utc']
    manifest['completion_audit_status'] = report['status']
    (ROOT/'run_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')


if __name__ == '__main__':
    main()
