#!/usr/bin/env python3
"""Reference-positive and intentionally incorrect-negative evaluator controls."""
import json
import re
from evaluate import ROOT, DATASET, evaluate, sha


def main():
    manifest = json.loads((ROOT / 'run_manifest.json').read_text())
    controls = []
    for task in manifest['problems']:
        name = task['problem_id']
        dest = ROOT / 'evaluation' / 'reference_controls' / name
        dest.mkdir(parents=True, exist_ok=True)
        ref = DATASET / (name + '_ref.sv')
        text, count = re.subn(r'\bmodule\s+RefModule\b', 'module TopModule',
                             ref.read_text(), count=1)
        assert count == 1, name
        source = dest / 'control_source.sv'
        source.write_text(text)
        result = evaluate(source, dest / 'run', name)
        controls.append({'problem_id': name, 'status': result['status'],
                         'official_reference_sha256': sha(ref),
                         'control_source_sha256': sha(source)})
    (ROOT / 'evaluation' / 'reference_controls.json').write_text(
        json.dumps(controls, indent=2) + '\n')
    assert all(c['status'] == 'passed' for c in controls)

    # Deliberately replace the official NOR function with OR. This control is
    # derived from official reference data after task selection, never from a
    # generated candidate, and is excluded from the pilot score.
    name = 'Prob013_m2014_q4e'
    dest = ROOT / 'evaluation' / 'negative_control'
    dest.mkdir(parents=True, exist_ok=True)
    original = (DATASET / (name + '_ref.sv')).read_text()
    assert 'assign out = ~(in1 | in2);' in original
    text = original.replace('module RefModule', 'module TopModule', 1)
    text = text.replace('assign out = ~(in1 | in2);', 'assign out = (in1 | in2);', 1)
    source = dest / 'control_source.sv'
    source.write_text(text)
    result = evaluate(source, dest / 'run', name)
    assert result['status'] == 'functional_failure', result['status']
    print(f'PASS: {len(controls)} correct references accepted; incorrect OR control rejected')


if __name__ == '__main__':
    main()
