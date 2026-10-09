#!/usr/bin/env python3
"""Drain a surviving pilot and restart both studies without participant hints."""
import datetime as dt
import json
import os
from pathlib import Path
import signal
import subprocess
import time

REPO = Path('/home/shmin/llm2rtl')
STORAGE = Path('/media/admin1/backup/shmin/llm2rtl_experiments')
ROOT = STORAGE / 'resource_restart_20261006_001'
OLD_TRIAL = STORAGE / 'isa_vs_direct_v1/calibration_002/I02/direct_fsm'
SURVIVING_PID = 922127
RUN_ID = 'calibration_resource_003'


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def save(path, data):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(data, indent=2) + '\n')
    tmp.replace(path)


def stage(value, **kwargs):
    save(ROOT / 'status.json', {'stage': value, 'updated_utc': now(),
         'main_runs_started': False, **kwargs})


def survivor_alive():
    try:
        proc = Path('/proc') / str(SURVIVING_PID)
        cmd = (proc / 'cmdline').read_bytes().replace(b'\0', b' ').decode(errors='replace')
        if str(OLD_TRIAL / 'candidate') not in cmd:
            return False
        return (proc / 'stat').read_text().split(') ', 1)[1].split()[0] != 'Z'
    except FileNotFoundError:
        return False


def memory_available():
    for line in Path('/proc/meminfo').read_text().splitlines():
        if line.startswith('MemAvailable:'):
            return int(line.split()[1]) * 1024
    raise RuntimeError('MemAvailable is unavailable')


def wait_for_memory():
    while memory_available() < 32 * 1024**3:
        stage('WAITING_FOR_AVAILABLE_MEMORY', available_bytes=memory_available(),
              minimum_available_bytes=32 * 1024**3)
        time.sleep(10)


def main():
    ROOT.mkdir(exist_ok=False)
    allowed = sorted(os.sched_getaffinity(0))[:8]
    env = dict(os.environ)
    for key in ['OMP_NUM_THREADS', 'OPENBLAS_NUM_THREADS', 'MKL_NUM_THREADS',
                'NUMEXPR_NUM_THREADS', 'VECLIB_MAXIMUM_THREADS']:
        env[key] = '2'
    save(ROOT / 'policy.json', {'cpu_affinity': allowed,
        'thread_environment': {k: env[k] for k in env if k.endswith('NUM_THREADS')},
        'order': ['drain_existing_I02_direct_fsm', 'ISA_vs_FSM_fresh_six', 'cold_start_fresh_two'],
        'memory_start_gate_bytes': 32 * 1024**3, 'memory_hard_limit': None,
        'note': 'Thread environment is a default; briefs also require one heavy tool and two Vivado threads.'})
    stage('DRAINING_EXISTING_PARTICIPANT', surviving_pid=SURVIVING_PID,
          trial=str(OLD_TRIAL))
    original = json.loads((OLD_TRIAL / 'status.json').read_text())
    deadline = dt.datetime.fromisoformat(original['started_utc']).timestamp() + 5400
    timed_out = False
    while survivor_alive():
        if time.time() >= deadline:
            timed_out = True
            os.killpg(SURVIVING_PID, signal.SIGTERM)
            time.sleep(2)
            if survivor_alive():
                os.killpg(SURVIVING_PID, signal.SIGKILL)
            break
        time.sleep(5)
    completed = False
    event_log = OLD_TRIAL / 'events.jsonl'
    for line in event_log.read_text(errors='replace').splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get('type') == 'turn.completed':
            completed = True
    save(OLD_TRIAL / 'resource_drain_result.json', {
         'observed_utc': now(), 'turn_completed_event': completed,
         'timeout_applied': timed_out, 'exit_code': None,
         'note': 'Original supervisor was stopped; no process exit code inferred.',
         'independent_acceptance': 'NOT_RUN'})
    original.update(status='TIMEOUT' if timed_out else
                    'PARTICIPANT_ENDED_REVIEW_REQUIRED' if completed else 'PROCESS_ENDED_REVIEW_REQUIRED',
                    ended_utc=now(), exit_code=None, independent_acceptance='NOT_RUN')
    save(OLD_TRIAL / 'status.json', original)
    for label, command, report_path, expected in [
        ('ISA_VS_FSM', ['python3', '-u', str(REPO / 'experiments/isa_vs_direct_integration_v1/scripts/run_calibration_pilots.py'), '--run-id', RUN_ID],
         STORAGE / 'isa_vs_direct_v1' / RUN_ID / 'status.json', 'PARTICIPANT_SESSIONS_ENDED_EVALUATION_PENDING'),
        ('COLD_START', ['python3', '-u', str(REPO / 'experiments/llm_accelerator_cold_start_v1/scripts/run_pilot.py')],
         STORAGE / 'cold_start_v1/supervisor_status.json', 'PILOT_PARTICIPANTS_ENDED_REVIEW_REQUIRED'),
    ]:
        wait_for_memory()
        with (ROOT / (label.lower() + '.log')).open('wb') as log:
            child = subprocess.Popen(command, cwd=REPO, env=env,
                stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                start_new_session=True, preexec_fn=lambda: os.sched_setaffinity(0, allowed))
            stage('RUNNING_' + label, child_pid=child.pid, live_status=str(report_path))
            if label == 'ISA_VS_FSM':
                path = REPO / 'experiments/isa_vs_direct_integration_v1/status.json'
                data = json.loads(path.read_text())
                data.update(stage='RESOURCE_CONTROLLED_CALIBRATION_RUNNING', active_run=RUN_ID,
                            supervisor_pid=child.pid, live_status=str(report_path),
                            participant_runs_started=0, restart_queue=str(ROOT / 'status.json'))
                save(path, data)
            else:
                path = REPO / 'experiments/llm_accelerator_cold_start_v1/launch.json'
                save(path, {'pid': child.pid, 'started_utc': now(), 'attempt': 4,
                     'participant_budget_seconds': 28800, 'implementation': 'direct Verilog/SystemVerilog; no HLS',
                     'supervisor_log': str(ROOT / 'cold_start.log'), 'resource_restart': True})
            code = child.wait()
        report = json.loads(report_path.read_text()) if report_path.exists() else {}
        if code or report.get('stage') != expected:
            stage('STOPPED_EXECUTION_ERROR', study=label, exit_code=code,
                  child_status=report, review_required=True)
            return
    stage('PARTICIPANTS_ENDED_INDEPENDENT_REVIEW_PENDING', independent_acceptance='NOT_RUN')


if __name__ == '__main__':
    main()
