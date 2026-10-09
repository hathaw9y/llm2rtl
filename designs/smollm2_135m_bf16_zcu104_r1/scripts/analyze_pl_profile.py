#!/usr/bin/env python3
"""Read profiler UART output. Cycle observations overlap and must not be summed."""
import argparse
import re
from pathlib import Path

NAMES = [
    'pl_busy', 'load_pending', 'store_pending', 'gemm_pending',
    'rms_pending', 'rope_pending', 'score_pending', 'softmax_pending',
    'value_pending', 'add_silu_pending', 'fence_wait', 'bank_dependency_wait',
    'issue_ready_wait', 'end_drain_wait', 'fence_load_pending',
    'fence_store_pending', 'fence_compute_pending', 'fence_bank_busy',
    'any_compute_pending', 'load_bytes', 'store_bytes', 'load_stream_stall',
    'store_stream_stall', 'load_compute_overlap',
]

def parse(text):
    runs = {}
    for line in text.splitlines():
        match = re.search(r'PERF_BLOCK (\w+) (\d+) (\d+) (\d+) (\d+)', line)
        if match:
            scope, start, end, chunks, wall = match.groups()
            runs[scope] = {'wall_us': int(wall), 'chunks': int(chunks), 'metrics': {}}
        match = re.search(r'PROFILE_PS (\w+) (.+)', line)
        if match and match[1] in runs:
            runs[match[1]]['ps'] = {k: int(v) for k, v in re.findall(r'(\w+)=(\d+)', match[2])}
        match = re.search(r'PROFILE_PL (\w+) (\d+) ([0-9a-fA-F]{8}) ([0-9a-fA-F]{8})', line)
        if match and match[1] in runs:
            scope, index, hi, lo = match.groups()
            runs[scope]['metrics'][int(index)] = (int(hi, 16) << 32) | int(lo, 16)
    return runs

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('uart', type=Path)
    parser.add_argument('--clock-mhz', type=float, default=100.0)
    args = parser.parse_args()
    if args.clock_mhz <= 0:
        parser.error('clock must be positive')
    text = args.uart.read_text(errors='replace')
    runs = parse(text)
    if 'BOARD PL PROFILE COMPLETE' not in text:
        parser.error('missing completion marker; rerun or capture the rest of the UART log')
    for scope in ('prefill32', 'decode1'):
        if scope not in runs or set(runs[scope]['metrics']) != set(range(24)):
            parser.error(f'{scope}: missing one or more of the 24 metrics')
        run = runs[scope]
        count = run['metrics']
        busy = count[0]
        if not busy:
            parser.error(f'{scope}: PL busy counter is zero')
        print(f"\n{scope}: wall={run['wall_us']/1e6:.6f}s chunks={run['chunks']}")
        if 'ps' in run:
            print('PS times: ' + ', '.join(f'{k}={v/1000:.3f}ms' for k,v in run['ps'].items()))
        print(f"{'metric':28} {'ms':>12} {'% PL busy':>12}")
        for i, name in enumerate(NAMES):
            if i in (19, 20):
                continue
            print(f'{name:28} {count[i]/args.clock_mhz/1000:12.3f} {100*count[i]/busy:12.3f}')
        for byte_index, pending_index in ((19,1), (20,2)):
            service_s = count[pending_index]/(args.clock_mhz*1e6)
            bandwidth = count[byte_index]/service_s/1e9 if service_s else 0
            print(f'{NAMES[byte_index]}={count[byte_index]} bytes, pending-interval rate={bandwidth:.3f} GB/s')
        print('Activity and FENCE reason rows overlap. Their percentages are not additive.')
        print('done_poll_us includes PL execution; readback_us is profiler overhead.')

if __name__ == '__main__':
    main()
