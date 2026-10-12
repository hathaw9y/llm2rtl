#!/usr/bin/env python3
"""Run a Vivado 2025.2 XSIM snapshot without its broken -runall Tcl wrapper."""
import os
import subprocess
import sys
from pathlib import Path

snapshot = Path(sys.argv[1]).resolve()
marker = sys.argv[2]
env = os.environ.copy()
vivado_root = Path(os.environ.get("XILINX_VIVADO", "/media/admin1/backup/tools/Xilinx/2025.2/Vivado"))
env["LD_LIBRARY_PATH"] = str(vivado_root / "lib/lnx64.o")
proc = subprocess.Popen(
    [str(snapshot)], cwd=snapshot.parents[2], env=env,
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    text=True, bufsize=1,
)
lines = []

def read_until(token):
    while True:
        line = proc.stdout.readline()
        if not line:
            raise RuntimeError(f"XSIM ended before {token}")
        lines.append(line)
        if token in line:
            return

read_until("=elaboration-done")
proc.stdin.write("-exec-run\n")
proc.stdin.flush()
read_until('reason="run-complete"')
proc.stdin.write("-exec-continue\n")
proc.stdin.flush()
read_until('reason="finish"')
proc.stdin.write("-gdb-exit\n")
proc.stdin.flush()
tail, _ = proc.communicate(timeout=20)
lines.append(tail)
text = "".join(lines)
sys.stdout.write(text)
if proc.returncode or marker not in text:
    raise SystemExit(1)
