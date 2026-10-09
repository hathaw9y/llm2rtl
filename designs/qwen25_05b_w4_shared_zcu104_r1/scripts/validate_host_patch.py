#!/usr/bin/env python3
"""Check real portable archives and idempotent patch application; no board access."""
import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            h.update(block)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('old', type=Path)
    p.add_argument('new', type=Path)
    p.add_argument('patch', type=Path)
    p.add_argument('report', type=Path)
    a = p.parse_args()
    archives = [a.old, a.new, a.patch]
    for archive in archives:
        with zipfile.ZipFile(archive) as z:
            if z.testzip() is not None:
                raise ValueError('ZIP CRC failure: ' + str(archive))
        expected = archive.with_suffix('.zip.sha256').read_text().split()[0]
        if sha(archive) != expected:
            raise ValueError('Archive SHA256 mismatch: ' + str(archive))
    with tempfile.TemporaryDirectory(prefix='qwen host patch with spaces ') as tmp:
        root = Path(tmp)
        for archive in archives:
            with zipfile.ZipFile(archive) as z:
                z.extractall(root)
        old = root / a.old.stem
        new = root / a.new.stem
        patch = root / a.patch.stem
        changes = json.loads((patch / 'patch_manifest.json').read_text())
        assert 'sd_card/QWEN.BIN' not in changes
        assert sha(old / 'sd_card/QWEN.BIN') == sha(new / 'sd_card/QWEN.BIN')
        for attempt in range(2):
            subprocess.run([sys.executable, str(patch / 'apply_patch.py'),
                            '--package', str(old)], check=True)
        checksums = json.loads((new / 'checksums.json').read_text())
        for name, digest in checksums.items():
            assert sha(old / name) == digest, name
        assert (old / 'checksums.json').read_bytes() == (new / 'checksums.json').read_bytes()
        loader = (old / 'load_board.tcl').read_text()
        artifacts = json.loads((new / 'artifact_manifest.json').read_text())['artifact_sha256']
        audit_names = [name for name in artifacts if Path(name).name == 'result.json']
        assert len(audit_names) == 1
        audit = json.loads((new / audit_names[0]).read_text())
        checks = audit['checks']
        setup = min(row['worst_slack_ns'] for row in checks['Setup']['clocks'])
        hold = min(row['worst_slack_ns'] for row in checks['Hold']['clocks'])
        pw = min(row['worst_slack_ns'] for row in checks['PW']['clocks'])
        expected_timing = f'Routed timing: setup{setup:+.3f}ns, hold{hold:+.3f}ns, pulse width{pw:+.3f}ns.'
        assert expected_timing in (new / 'README.txt').read_text()
        assert 'dow -data' not in loader
        assert 'PL_CONTROL_PREFLIGHT_PASS' in loader
        assert loader.index('PL_CONTROL_PREFLIGHT_PASS') < loader.index('\ncon\n')
        assert loader.count('mrd -force -value') == 2
        assert not (old / 'dumps').exists()
        assert not (old / 'uart.log').exists()
        assert json.loads((old / 'artifact_manifest.json').read_text())['board_reset_check']['status'].startswith('passed')
        # Stub hardware commands only; never produce board UART or dump bytes.
        harness = root / 'loader_stub.tcl'
        harness.write_text('''set root [lindex $argv 0]
set profile [lindex $argv 1]
set status [lindex $argv 2]
set executions 0
set downloads 0
set dumps 0
rename source real_source
proc source {path} {
    if {[file tail $path] eq "psu_init.tcl"} {return}
    uplevel 1 [list real_source $path]
}
foreach name {connect targets rst fpga configparams psu_init psu_post_config psu_ps_pl_isolation_removal psu_ps_pl_reset_config stop} {
    proc $name {args} {return}
}
proc dow {args} {
    if {[lindex $args 0] eq "-data"} {error "Unexpected JTAG model download"}
    if {![file isfile [lindex $args 0]]} {error "Missing ELF"}
    incr ::downloads
}
proc con {} {incr ::executions}
proc mrd {args} {
    if {[lindex $args 0] eq "-bin"} {incr ::dumps; return}
    if {[lrange $args 0 1] ne {-force -value}} {error "Expected forced value read"}
    if {[lindex $args 2] eq "0xA0010018"} {return $::profile}
    if {[lindex $args 2] eq "0xA0010004"} {return $::status}
    error "Unexpected register address"
}
set failed [catch {source [file join $root load_board.tcl]} message]
if {$profile == 0x51574E31 && !($status & 0xD)} {
    if {$failed || $executions != 1 || $downloads != 1} {error "Valid load failed: $message"}
    source [file join $root dump_board.tcl]
    if {$dumps != 4} {error "Incorrect dump command count"}
} else {
    if {!$failed || $executions != 0 || $downloads != 0} {error "Bad preflight did not block CPU"}
}
puts "STUBBED_HOST_CONTROL_PASS_NO_BOARD_ACCESS"
''')
        for profile, status in [('0x51574E31', '0'), ('0', '0'),
                                ('0x51574E31', '8'), ('0x51574E31', '4')]:
            subprocess.run(['tclsh', str(harness), str(old), profile, status], check=True)
        assert not list((old / 'dumps').iterdir())
    result = {
        'status': 'passed_real_archives_and_relocated_idempotent_host_patch',
        'physical_board_execution': False,
        'checks': ['ZIP CRC and SHA256', 'relocated path containing spaces',
                   'actual patch applied twice', 'all new package checksums match',
                   'SD QWEN.BIN unchanged and absent from patch',
                   'relocated Tcl with hardware stubs; profile/reset/error failures block CPU',
                   'PL preflight precedes CPU execution', 'no FPGA output fabricated'],
        'archive_sha256': {str(f): sha(f) for f in archives},
        'changed_files': len(changes),
    }
    a.report.write_text(json.dumps(result, indent=2) + '\n')
    print(result['status'])


if __name__ == '__main__':
    main()
