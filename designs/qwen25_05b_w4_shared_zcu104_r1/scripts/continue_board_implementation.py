#!/usr/bin/env python3
"""Continue a routed board checkpoint in a fresh cloned build, keeping RTL/clocks fixed."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

BASE = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('prior', type=Path)
    parser.add_argument('out', type=Path)
    args = parser.parse_args()
    prior, out = args.prior.resolve(), args.out.resolve()
    if not (prior / 'invocation.json').exists():
        raise ValueError('Prior build must have finished before continuation')
    if not (prior / 'routed.dcp').exists():
        raise ValueError('Prior routed checkpoint missing')
    shutil.copytree(prior, out, ignore=shutil.ignore_patterns('.Xil', 'tmp'))
    for name in ['invocation.json', 'qwen.bit', 'qwen.hwh', 'qwen.xsa']:
        (out / name).unlink(missing_ok=True)
    script = BASE / 'scripts/continue_board_implementation.tcl'
    frozen = out / 'source/continue_board_implementation.tcl'
    shutil.copyfile(script, frozen)
    manifest = json.loads((out / 'manifest.json').read_text())
    manifest['implementation_continuation'] = {
        'prior': str(prior),
        'prior_routed_DCP_sha256': hashlib.sha256((prior / 'routed.dcp').read_bytes()).hexdigest(),
        'script_sha256': hashlib.sha256(frozen.read_bytes()).hexdigest(),
        'scope': 'Post-route physical optimization only; original RTL and 5ns clocks unchanged',
    }
    manifest['build_source_sha256'][frozen.relative_to(out / 'source').as_posix()] = hashlib.sha256(frozen.read_bytes()).hexdigest()
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (out / 'tmp').mkdir()
    environment = os.environ.copy()
    environment['TMPDIR'] = str(out / 'tmp')
    start = time.monotonic()
    with (out / 'continuation_console.log').open('w') as log:
        result = subprocess.run([
            '/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin/vivado',
            '-mode', 'batch', '-nojournal', '-log', str(out / 'continuation_vivado.log'),
            '-source', str(frozen), '-tclargs', str(out),
        ], cwd=out, env=environment, stdout=log, stderr=subprocess.STDOUT)
    (out / 'invocation.json').write_text(json.dumps({
        'returncode': result.returncode, 'seconds': time.monotonic() - start,
        'stage': 'post_route_physical_optimization',
    }, indent=2) + '\n')
    print('board continuation returncode', result.returncode, flush=True)
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
