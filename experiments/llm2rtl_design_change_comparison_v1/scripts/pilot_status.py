#!/usr/bin/env python3
"""Read supervisor progress without touching participant resources."""
import json
from pathlib import Path

base = Path('/media/admin1/backup/shmin/llm2rtl_experiments/design_change_v1')
queue = json.loads((base / 'pilot_queue_status.json').read_text())
common = base / 'common_audits/supervisor_status.json'
result = {'queue': queue, 'trials': [],
          'common': json.loads(common.read_text()) if common.exists() else None}
for path in sorted((base / 'pilot').glob('*/*/status.json')):
    metadata = json.loads(path.read_text())
    trial = {k: metadata.get(k) for k in ['task', 'condition', 'status', 'elapsed_seconds']}
    trial['reports'] = {}
    for phase in ['public', 'hidden']:
        for filename in ['result.json', 'report.json']:
            report = path.parent / ('evaluation_' + phase) / filename
            if report.exists():
                data = json.loads(report.read_text())
                passed = data.get('passed')
                if 'functional' in data:
                    passed = all(x.get('passed') for x in data['functional'])
                    structure = data.get('structural')
                    if phase == 'public':
                        passed = passed and isinstance(structure, dict) and structure.get('passed', False)
                trial['reports'][phase] = {'passed': data.get('passed'), 'status': data.get('status'),
                                           'gates': {k: v.get('status') for k, v in data.get('gates', {}).items()}}
                trial['reports'][phase]['passed'] = passed
                if 'functional' in data:
                    trial['reports'][phase]['cases'] = sum(x.get('case_count', 0) for x in data['functional'])
                    trial['reports'][phase]['structural'] = data.get('structural')
                break
    asset_report = path.parent / 'evaluation_static_assets/asset_report.json'
    if asset_report.exists():
        data = json.loads(asset_report.read_text())
        trial['reports']['static_assets'] = {'status': data.get('status'), 'error': data.get('error')}
    if metadata['status'] == 'RUNNING':
        latest = ''
        for line in (path.parent / 'events.jsonl').read_text(errors='replace').splitlines():
            try:
                event = json.loads(line)
            except ValueError:
                continue
            item = event.get('item', {})
            if item.get('type') == 'agent_message':
                latest = item.get('text', '')
        trial['latest_participant_update'] = latest[:650]
    result['trials'].append(trial)
print(json.dumps(result))
