#!/usr/bin/env python3
"""Independent paired aggregation, including verified benchmark-invalid tasks."""
import collections
import json
import math
import statistics
from pathlib import Path
from official_verdict import normalize_completed_run

ROOT = Path(__file__).resolve().parent


def main():
    normalize_completed_run()
    manifest = json.loads((ROOT / 'run_manifest.json').read_text())
    validity = json.loads((ROOT / 'benchmark_validity.json').read_text())
    invalid = set(validity['invalid_problems'])
    records = {}
    for job in manifest['jobs']:
        path = Path(job['directory']) / 'run_result.json'
        if path.exists():
            records[(job['mode'], job['problem_id'])] = json.loads(path.read_text())
    if len(records) != manifest['total_generation_jobs']:
        raise RuntimeError(f'Full experiment incomplete: {len(records)}/312')
    report = {'model': manifest['model'], 'dataset_commit': manifest['dataset_commit'],
              'status': 'completed', 'total_jobs': len(records),
              'invalid_tasks': validity['invalid_problems'], 'conditions': {}, 'pairs': {}}
    for mode in manifest['conditions']:
        all_rows = [r for (m, _), r in records.items() if m == mode]
        valid = [r for r in all_rows if r['problem_id'] not in invalid]
        seconds = [r['generation']['seconds'] for r in all_rows]
        usages = [r['generation'].get('usage') or {} for r in all_rows]
        passed = sum(r['official_status'] == 'passed' for r in valid)
        report['conditions'][mode] = {
            'attempted': len(all_rows), 'valid_tasks': len(valid),
            'invalid_tasks': len(all_rows) - len(valid),
            'valid_official_passed': passed,
            'valid_final_functional_success_rate': passed / len(valid),
            'raw_official_passed': sum(r['official_status'] == 'passed' for r in all_rows),
            'raw_official_rate_including_invalid': sum(r['official_status'] == 'passed' for r in all_rows) / len(all_rows),
            'official_passed_all_156': sum(r['official_status'] == 'passed' for r in all_rows),
            'official_final_functional_success_rate_all_156': sum(r['official_status'] == 'passed' for r in all_rows) / len(all_rows),
            'official_initial_passed_all_156': sum(bool(r['initial']) and r['initial']['status'] == 'passed' for r in all_rows),
            'official_initial_pass_at_1_all_156': sum(bool(r['initial']) and r['initial']['status'] == 'passed' for r in all_rows) / len(all_rows),
            'workflow_passed_all_156': sum(r['workflow_status'] == 'passed' for r in all_rows),
            'valid_workflow_passed': sum(r['workflow_status'] == 'passed' for r in valid),
            'valid_initial_passed': sum(bool(r['initial']) and r['initial']['status'] == 'passed' for r in valid),
            'generation_seconds_mean': statistics.mean(seconds),
            'generation_seconds_median': statistics.median(seconds),
            'generation_seconds_total': sum(seconds),
            'revision_count_distribution': dict(collections.Counter(str(r['revision_count']) for r in all_rows)),
            'revisions_total': sum(r['revision_count'] or 0 for r in all_rows),
            'token_usage_available_jobs': sum(bool(r['generation'].get('usage')) for r in all_rows),
            'input_tokens_total': sum(u.get('input_tokens', 0) for u in usages),
            'cached_input_tokens_total': sum(u.get('cached_input_tokens', 0) for u in usages),
            'output_tokens_total': sum(u.get('output_tokens', 0) for u in usages),
            'reasoning_output_tokens_total': sum(u.get('reasoning_output_tokens', 0) for u in usages),
            'valid_failure_types': dict(collections.Counter(r['official_status'] for r in valid if r['official_status'] != 'passed')),
            'development_passed': sum(r.get('development_status') == 'passed' for r in all_rows),
            'development_simulation_ran': sum(bool(r.get('development_simulation_ran')) for r in all_rows),
            'development_checks_total': sum(r.get('development_check_count', 0) for r in all_rows),
            'development_failed_checks_total': sum(r.get('development_failed_check_count', 0) for r in all_rows),
            'observed_checked_rtl_revisions_total': sum(r.get('observed_checked_rtl_revisions', 0) for r in all_rows),
            'protocol_issues': dict(collections.Counter(issue for r in all_rows for issue in r['protocol_issues']))}
    pairs = {k: [] for k in ('both_pass', 'single_only', 'contract_only', 'both_fail')}
    for name in manifest['problems']:
        if name in invalid:
            continue
        a = records[('single_agent', name)]['official_status'] == 'passed'
        b = records[('contract_based', name)]['official_status'] == 'passed'
        key = 'both_pass' if a and b else 'single_only' if a else 'contract_only' if b else 'both_fail'
        pairs[key].append(name)
    report['pairs'] = pairs
    a, b = len(pairs['single_only']), len(pairs['contract_only'])
    n = a + b
    report['paired_exact_mcnemar_p_two_sided'] = (
        min(1.0, 2 * sum(math.comb(n, i) for i in range(min(a, b) + 1)) / 2**n) if n else 1.0)
    report['statistics_note'] = 'One sample per task per arm; paired test is exploratory and does not estimate repeated-generation variability.'
    report['limitations'] = manifest['limitations']
    (ROOT / 'final_comparison.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
