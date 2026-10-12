#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path

work = Path(sys.argv[1]).resolve()
log = Path(sys.argv[2]).resolve()
kernel = work / "xsim.dir/stream_bank_adapters_sim/xsimk"
env = os.environ.copy()
env["LD_LIBRARY_PATH"] = "/media/admin1/backup/tools/Xilinx/2025.2/Vivado/lib/lnx64.o"
p = subprocess.Popen([str(kernel)], cwd=work, env=env, stdin=subprocess.PIPE,
                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                     text=True, bufsize=1)
lines = []

def until(marker: str) -> None:
    while True:
        line = p.stdout.readline()
        if not line:
            raise RuntimeError(f"XSIM ended before {marker}")
        lines.append(line)
        if marker in line:
            return

until("=elaboration-done")
p.stdin.write("-exec-run\n")
p.stdin.flush()
until('reason="run-complete"')
p.stdin.write("-exec-continue\n")
p.stdin.flush()
until('reason="finish"')
p.stdin.write("-gdb-exit\n")
p.stdin.flush()
tail, _ = p.communicate(timeout=20)
lines.append(tail)
text = "".join(lines)
log.write_text(text, encoding="utf-8")
marker = "PASS stream_bank_adapters randomized stalls full partial abort reset repeated no_duplicate"
if p.returncode or text.count(f'@"{marker}\\n"') != 1:
    raise RuntimeError("XSIM failed or exact PASS marker missing")
print(marker)
