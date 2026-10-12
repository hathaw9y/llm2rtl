#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[4]
log = Path(sys.argv[1]).resolve()
commands = [["verilator", "--version"], [
    "verilator", "--lint-only", "--sv", "-Wall", "-Wno-LITENDIAN",
    "-Wno-UNUSED", "-Wno-DECLFILENAME", "--top-module",
    "sparse_isa_dispatcher",
    str(root / "ip/infrastructure/bank_sparse_router/rtl/bank_config_pkg.sv"),
    str(root / "ip/infrastructure/sparse_isa_dispatcher/rtl/sparse_isa_dispatcher.sv")
]]
lines = []
for command in commands:
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)
    lines.append("$ " + " ".join(command) + "\n" + result.stdout +
                 f"exit_code={result.returncode}\n")
    if result.returncode:
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text("\n".join(lines), encoding="utf-8")
        raise SystemExit(result.returncode)
log.parent.mkdir(parents=True, exist_ok=True)
log.write_text("\n".join(lines), encoding="utf-8")
print("SPARSE_ISA_DISPATCHER_VERILATOR_LINT_PASS")
