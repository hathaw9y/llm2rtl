#!/usr/bin/env python3
"""Continue the already authorized pilot queue, without participant feedback."""
import datetime as dt
import json
from pathlib import Path
import subprocess
import time
import argparse

p = argparse.ArgumentParser()
p.add_argument('--storage', type=Path, required=True)
a = p.parse_args()
status = a.storage / 'pilot_queue_status.json'

def update(stage, **data):
    status.write_text(json.dumps({'stage': stage, 'updated_utc': dt.datetime.now(dt.timezone.utc).isoformat(), **data}, indent=2) + '\n')

update('WAITING_FOR_T03_PAIR', main_trials_started=False)
start = time.monotonic()
finished = a.storage / 'pilot/T03/supervisor_status.json'
while not finished.exists():
    launch = json.loads((a.storage / 'pilot_t03_launch.json').read_text())
    if not Path('/proc/' + str(launch['pid'])).exists():
        update('STOPPED_INFRASTRUCTURE_ERROR', detail='T03 supervisor exited without pair completion')
        raise SystemExit(1)
    if time.monotonic() - start > 5 * 3600:
        update('STOPPED_SUPERVISOR_TIMEOUT', detail='Review T03 supervisor; no automatic restart')
        raise SystemExit(1)
    time.sleep(10)

runner = Path(__file__).with_name('run_pilot_pair.py')
for task in ['T01', 'T02']:
    update('RUNNING_' + task + '_PAIR', main_trials_started=False)
    result = subprocess.run(['python3', '-u', str(runner), '--storage', str(a.storage), '--task', task])
    if result.returncode:
        update('STOPPED_INFRASTRUCTURE_ERROR', task=task, exit_code=result.returncode)
        raise SystemExit(result.returncode)
update('SIX_PILOT_PARTICIPANT_SESSIONS_FINISHED', main_trials_started=False,
       acceptance='Task-specific reports plus independent common-gate review required; no all-gates success inferred.')
