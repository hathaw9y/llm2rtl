#!/usr/bin/env python3
"""Execute the pinned official analyze_result function without unused SDK imports."""
import ast
import dataclasses
import hashlib
import json
import re
import sys
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ANALYZER = Path('/tmp/llm2rtl_verilogeval_20260930/scripts/sv-iv-analyze')


def official_function():
    original = ast.parse(ANALYZER.read_text())
    nodes = [n for n in original.body if isinstance(n, (ast.ClassDef, ast.FunctionDef))
             and n.name in ('ResultRecord', 'analyze_result')]
    assert len(nodes) == 2
    module = types.ModuleType('_pinned_official_verilogeval_analyzer')
    module.re = re
    module.dataclass = dataclasses.dataclass
    sys.modules[module.__name__] = module
    exec(compile(ast.Module(body=nodes, type_ignores=[]), str(ANALYZER), 'exec'), module.__dict__)
    return module.analyze_result


def verdict(directory):
    directory = Path(directory)
    generate_log = directory / 'official_generation_log.txt'
    generate_log.write_text('')
    combined = directory / 'official_combined_test.log'
    log = ((directory / 'compile.log').read_text() +
           ((directory / 'simulation.log').read_text()
            if (directory / 'simulation.log').exists() else ''))
    metadata = json.loads((directory / 'result.json').read_text())
    if metadata['compile'].get('timeout') or (metadata.get('simulation') or {}).get('timeout'):
        log += '\nTIMEOUT\n'
    combined.write_text(log)
    class Capture:
        def add_result(self, problem, sample, record):
            self.record = record
    capture = Capture()
    official_function()(capture, 'control', '1', str(generate_log),
                        str(combined), str(directory / 'candidate.sv'))
    return dataclasses.asdict(capture.record)


def normalize_completed_run():
    manifest = json.loads((ROOT / 'run_manifest.json').read_text())
    paths = [Path(j['directory']) / 'run_result.json' for j in manifest['jobs']]
    assert all(p.exists() for p in paths), 'Cannot normalize an incomplete full experiment'
    changes = []
    for job, path in zip(manifest['jobs'], paths):
        result = json.loads(path.read_text())
        for which in ('initial', 'final'):
            evaluation = result.get(which)
            if not evaluation:
                continue
            directory = ROOT / 'evaluation' / job['mode'] / job['problem_id'] / which
            record = verdict(directory)
            old = evaluation.get('pre_official_analyzer_status', evaluation['status'])
            evaluation['pre_official_analyzer_status'] = old
            evaluation['official_analyzer_record'] = record
            code = record['passfail']
            new = ('passed' if code == '.' else 'testbench_timeout' if code == 'T' else
                   'official_analyzer_rejection' if old == 'passed' else old)
            evaluation['status'] = new
            if old != new:
                changes.append({'mode': job['mode'], 'problem_id': job['problem_id'],
                                'candidate': which, 'before': old, 'after': new, 'official_code': code})
            (directory / 'result.json').write_text(json.dumps(evaluation, indent=2) + '\n')
        result['official_status'] = result['final']['status'] if result['final'] else 'generation_failure'
        result['official_analyzer_code'] = (result['final']['official_analyzer_record']['passfail']
                                            if result['final'] else None)
        result['workflow_status'] = ('passed' if result['official_status'] == 'passed'
                                     and not result['protocol_issues'] else 'failed')
        path.write_text(json.dumps(result, indent=2) + '\n')
    audit = {'official_analyzer_sha256': hashlib.sha256(ANALYZER.read_bytes()).hexdigest(),
             'changed_verdicts': changes, 'generation_rerun': False, 'rtl_modified': False}
    (ROOT / 'official_verdict_audit.json').write_text(json.dumps(audit, indent=2) + '\n')
    return audit


def main():
    manifest = json.loads((ROOT / 'run_manifest.json').read_text())
    controls = []
    invalid = {}
    for name in manifest['problems']:
        d = ROOT / 'evaluation' / 'reference_controls' / name / 'run'
        record = verdict(d)
        controls.append({'problem_id': name, 'official_code': record['passfail']})
        if record['passfail'] != '.':
            invalid[name] = {'official_reference_code': record['passfail'],
                             'reason': ('Official prompt/reference expose Y1/Y3 but testbench connects Y2/Y4'
                                        if name == 'Prob099_m2014_q6c' else
                                        'Official reference reaches testbench TIMEOUT marker; pinned official analyzer rejects it'),
                             'original_files_modified': False,
                             'generation_and_raw_evaluation': 'Both arms still run; include in 156-task official score, separately report reference-valid score'}
    validity = {'reference_control_total': len(controls),
                'official_reference_passed': len(controls) - len(invalid),
                'valid_task_count': len(controls) - len(invalid),
                'invalid_problems': invalid,
                'official_analyzer_sha256': hashlib.sha256(ANALYZER.read_bytes()).hexdigest(),
                'official_analyzer_loading': 'Unmodified AST nodes ResultRecord and analyze_result; unrelated langchain imports and CLI/report renderer are not loaded',
                'reference_codes': controls}
    (ROOT / 'benchmark_validity.json').write_text(json.dumps(validity, indent=2) + '\n')
    print('Official reference controls:', validity['official_reference_passed'], '/', len(controls))
    print('Reference failures:', invalid)


if __name__ == '__main__':
    main()
