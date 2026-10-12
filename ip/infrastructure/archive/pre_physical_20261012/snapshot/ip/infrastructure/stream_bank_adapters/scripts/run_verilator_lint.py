#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = Path(sys.argv[1]).resolve()
commands = []
for top in ("mm2s_stream_bank_adapter", "s2mm_stream_bank_adapter"):
    cmd = [
        "verilator", "--lint-only", "-Wall", "-Wno-DECLFILENAME",
        "--top-module", top, str(root / "rtl" / f"{top}.sv")
    ]
    run = subprocess.run(cmd, text=True, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT)
    commands.append("$ " + " ".join(cmd) + "\n" + run.stdout +
                    f"exit_code={run.returncode}\n")
    if run.returncode:
        out.write_text("\n".join(commands), encoding="utf-8")
        raise SystemExit(run.returncode)
out.write_text("\n".join(commands), encoding="utf-8")
print("PASS Verilator DUT-only lint tops=2 warnings=0")
