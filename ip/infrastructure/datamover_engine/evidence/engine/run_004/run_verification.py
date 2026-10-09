#!/usr/bin/env python3
"""Verify captured RTL with 64/128-bit DMA streams; preserve logs, discard scratch."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

RUN = Path(__file__).resolve().parent
SNAPSHOT = RUN / 'source_snapshot'
RTL = SNAPSHOT / 'rtl'
SOURCES = [RTL / (name + '.sv') for name in (
    'datamover_engine_pkg', 'fifo', 'pipeline', 'datamover_command_queue',
    'mm2s_channel', 's2mm_channel', 'datamover_engine', 'axis_width_converter',
    'axis_width_down_converter', 'axis_width_up_converter', 'mm2s_adapter',
    's2mm_adapter', 'bank_read_arbit', 'bank_write_arbit', 'bank_arbiter', 'bram_bank')]
SOURCES += [RUN / 'verification_sources' / name for name in (
    'integration_bank.sv', 'tb_engine_integration.sv')]


def execute(command, work, output):
    with output.open('w') as log:
        result = subprocess.run(command, cwd=work, stdout=log, stderr=subprocess.STDOUT,
                                timeout=120, check=False)
    return result.returncode


results = []
for stream in (64, 128):
    for bank in (32, 128):
        for latency in (1, 3):
            name = f'dma{stream}_bank{bank}_lat{latency}'
            logs = RUN / 'integration' / name
            logs.mkdir(parents=True, exist_ok=False)
            item = {'case': name, 'dma_width': stream, 'bank_width': bank, 'read_latency': latency}
            with tempfile.TemporaryDirectory(prefix='datamover-xsim-') as folder:
                work = Path(folder)
                compile_code = execute(['xvlog', '-sv', *map(str, SOURCES)], work, logs / 'compile.txt')
                item['compile_exit'] = compile_code
                if compile_code:
                    item['status'] = 'compile_failed'
                else:
                    elaborate_code = execute([
                        'xelab', 'tb_engine_integration', '-L', 'xpm', '-s', 'integration_sim',
                        '-timescale', '1ns/1ps', '-generic_top', f'DMA_DATA_WIDTH={stream}',
                        '-generic_top', f'BANK_DATA_WIDTH={bank}', '-generic_top', f'BANK_READ_LAT={latency}'
                    ], work, logs / 'elaborate.txt')
                    item['elaborate_exit'] = elaborate_code
                    if elaborate_code:
                        item['status'] = 'elaborate_failed'
                    else:
                        code = execute([
                            sys.executable, str(SNAPSHOT / 'scripts/run_xsimk.py'),
                            str(work / 'xsim.dir/integration_sim/xsimk'), 'PASS integration '
                        ], work, logs / 'simulation.txt')
                        output = (logs / 'simulation.txt').read_text()
                        item['simulation_exit'] = code
                        # xsimk emits program output as MI @"...\n" records.
                        # Decode those records before matching a standalone marker.
                        messages = ''.join(json.loads(line[1:]) for line in output.splitlines()
                                           if line.startswith('@"'))
                        (logs / 'program_output.txt').write_text(messages)
                        item['pass_marker'] = bool(re.search(r'^PASS integration .+$', messages, re.M))
                        item['unexpected_error'] = bool(re.search(r'Fatal:|FATAL:|ERROR:', output))
                        item['status'] = ('passed' if code == 0 and item['pass_marker']
                                          and not item['unexpected_error'] else 'simulation_failed')
            results.append(item)
            (RUN / 'integration_results.json').write_text(json.dumps(results, indent=2) + '\n')
            print(name, item['status'], flush=True)
            if item['status'] != 'passed':
                raise SystemExit(1)
(RUN / 'simulation_source_manifest.json').write_text(json.dumps([
    {'path': str(path.relative_to(RUN)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    for path in SOURCES + [Path(__file__), SNAPSHOT / 'scripts/run_xsimk.py']
], indent=2) + '\n')
