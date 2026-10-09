#!/usr/bin/env python3
"""Materialize the native template and execute isolated, source-bound checks."""
import argparse, hashlib, json, os, subprocess, time, queue, threading, shutil
from pathlib import Path
from materialize_probe import materialize_probe
ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'ip/infrastructure/bank_subsystem_template'
VIVADO = Path(os.environ.get('VIVADO_BIN', '/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin'))

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def command(args, work, name):
    with (work / name).open('w') as log:
        p = subprocess.run([str(x) for x in args], cwd=work, stdout=log, stderr=subprocess.STDOUT, timeout=600)
    (work / (name + '.exit')).write_text(str(p.returncode) + '\n')
    if p.returncode:
        raise RuntimeError(f'{name} failed ({p.returncode}); see {work / name}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', type=Path)
    ap.add_argument('--mode', choices=['sim', 'synth', 'prepare'], default='sim')
    opts = ap.parse_args()
    out = (opts.out or BASE / 'evidence' / ('native_' + time.strftime('%Y%m%d_%H%M%S'))).resolve()
    out.mkdir(parents=True, exist_ok=False)
    generated = out / 'generated'
    generated.mkdir()
    replacements = {'{{PACKAGE_NAME}}': 'native_test_config_pkg', '{{MODULE_NAME}}': 'native_test_bank_subsystem', 'bank_native_config_pkg': 'native_test_config_pkg', 'module bank_subsystem': 'module native_test_bank_subsystem'}
    templates = sorted((BASE / 'rtl').glob('*.tpl'))
    if len(templates) != 2:
        raise RuntimeError('Expected exactly the package and subsystem templates')
    for source in templates:
        data = source.read_text()
        for before, after in replacements.items():
            data = data.replace(before, after)
        if '{{' in data:
            raise RuntimeError(f'Unresolved template token in {source}')
        (generated / source.name.removesuffix('.tpl')).write_text(data)
    sources = [generated / 'bank_config_pkg.sv']
    sources += sorted((ROOT / 'ip/infrastructure/bank_subsystem/rtl').glob('bank_native_*.sv'))
    sources += [ROOT / 'ip/infrastructure/datamover_engine/rtl/bram_bank.sv', ROOT / 'ip/infrastructure/datamover_engine/rtl/uram_bank.sv', generated / 'bank_subsystem.sv']
    extension_sources = materialize_probe(BASE, generated)
    tests = sorted((BASE / 'tb').glob('*.sv'))
    contract = ROOT / 'ip/infrastructure/bank_subsystem/contracts/native_v3.json'
    manifest = {'schema': 'native_bank_check.v1', 'part': 'xczu7ev-ffvc1156-2-e', 'clock_ns': 5.0,
                'top': 'native_test_bank_subsystem', 'mode': opts.mode,
                'sources': {str(p): digest(p) for p in sources + extension_sources + tests + templates + [BASE / "scripts/materialize_probe.py", contract, ROOT / "contracts/common/engine_completion_contract.json", Path(__file__).resolve(), BASE / 'scripts/native_ooc.tcl']}}
    command([VIVADO / 'vivado', '-version'], out, 'version.log')
    manifest['tool_version'] = (out / 'version.log').read_text()
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    for name, expected in manifest['sources'].items():
        source = Path(name)
        try: relative = source.relative_to(ROOT)
        except ValueError: relative = Path('generated') / source.name
        target = out / 'source_snapshot' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        if digest(target) != expected: raise RuntimeError('Snapshot identity changed')
    if opts.mode == 'prepare':
        print(out)
        return
    if opts.mode == 'synth':
        (out / 'sources.tcl').write_text('\n'.join('read_verilog -sv {' + str(p) + '}' for p in sources) + '\n')
        command([VIVADO / 'vivado', '-mode', 'batch', '-source', BASE / 'scripts/native_ooc.tcl', '-tclargs', out], out, 'synth.log')
        if 'NATIVE_BANK_OOC_PASS' not in (out / 'synth.log').read_text().splitlines():
            raise RuntimeError('Missing exact OOC completion marker')
    else:
        command([VIVADO / 'xvlog', '--sv', *sources, extension_sources[0], extension_sources[1], *tests], out, 'compile.log')
        command([VIVADO / 'xelab', 'tb_bank_native', '-L', 'xpm', '-s', 'native_bank_sim', '-timescale', '1ns/1ps'], out, 'elaborate.log')
        run_kernel(out, 'native_bank_sim', 'NATIVE_BANK_XSIM_PASS', 'simulation.log')
        command([VIVADO / 'xelab', 'tb_bank_extension', '-L', 'xpm', '-s', 'native_extension_sim', '-timescale', '1ns/1ps'], out, 'extension_elaborate.log')
        run_kernel(out, 'native_extension_sim', 'NATIVE_EXTENSION_XSIM_PASS', 'extension_simulation.log')
    for name, expected in manifest['sources'].items():
        if digest(Path(name)) != expected: raise RuntimeError('Source changed during run: ' + name)
    print(out)


def run_kernel(out, snapshot, marker, logname):
    env = os.environ.copy()
    env['LD_LIBRARY_PATH'] = str(VIVADO.parent / 'lib/lnx64.o')
    p = subprocess.Popen([str(out / ('xsim.dir/' + snapshot + '/xsimk'))], cwd=out, env=env,
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines = []
    messages = queue.Queue()
    def pump():
        for line in p.stdout:
            messages.put(line)
        messages.put(None)
    threading.Thread(target=pump, daemon=True).start()
    deadline = time.monotonic() + 120
    def until(marker):
        while True:
            line = messages.get(timeout=max(0.01, deadline - time.monotonic()))
            if not line:
                raise RuntimeError(f'XSIM ended before {marker}')
            lines.append(line)
            if marker in line:
                return
    try:
        until('=elaboration-done')
        p.stdin.write('-exec-run\n'); p.stdin.flush()
        until('reason="run-complete"')
        p.stdin.write('-exec-continue\n'); p.stdin.flush()
        until('reason="finish"')
        p.stdin.write('-gdb-exit\n'); p.stdin.flush()
        p.wait(timeout=20)
        while not messages.empty():
            tail = messages.get_nowait()
            if tail is not None: lines.append(tail)
    finally:
        if p.poll() is None:
            p.kill(); p.wait()
        (out / logname).write_text(''.join(lines))
        (out / (logname + '.exit')).write_text(str(p.returncode) + '\n')
    decoded = ''.join(json.loads(line[1:].strip()) for line in lines if line.startswith('@'))
    (out / (logname + '.stdout')).write_text(decoded)
    if p.returncode or marker not in decoded.splitlines():
        raise RuntimeError(f'XSIM failed or exact PASS absent: {out / "simulation.log"}')

if __name__ == '__main__':
    main()
