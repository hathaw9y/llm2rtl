#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path

work = Path(sys.argv[1]).resolve()
log = Path(sys.argv[2]).resolve()
snapshot = sys.argv[3]
marker = sys.argv[4]
env = os.environ.copy()
env["LD_LIBRARY_PATH"] = "/media/admin1/backup/tools/Xilinx/2025.2/Vivado/lib/lnx64.o"
process = subprocess.Popen(
    [str(work / "xsim.dir" / snapshot / "xsimk")], cwd=work, env=env,
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    text=True, bufsize=1)
lines = []

def read_until(token):
    while True:
        line = process.stdout.readline()
        if not line:
            raise RuntimeError(f"XSIM ended before {token}")
        lines.append(line)
        if token in line:
            return

read_until("=elaboration-done")
process.stdin.write("-exec-run\n")
process.stdin.flush()
read_until('reason="run-complete"')
process.stdin.write("-exec-continue\n")
process.stdin.flush()
read_until('reason="finish"')
process.stdin.write("-gdb-exit\n")
process.stdin.flush()
tail, _ = process.communicate(timeout=20)
lines.append(tail)
text = "".join(lines)
log.write_text(text, encoding="utf-8")
if process.returncode or marker not in text:
    raise RuntimeError("XSIM independent regression failed")
print(marker)
