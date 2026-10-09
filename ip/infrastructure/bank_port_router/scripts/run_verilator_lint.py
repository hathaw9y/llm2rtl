#!/usr/bin/env python3
from pathlib import Path
import argparse,subprocess
ap=argparse.ArgumentParser();ap.add_argument("--evidence-dir",required=True,type=Path);a=ap.parse_args();root=Path(__file__).resolve().parents[1];a.evidence_dir.mkdir(parents=True,exist_ok=True)
v=subprocess.run(["verilator","--version"],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(a.evidence_dir/"verilator_version.log").write_text(v.stdout,encoding="utf-8")
p=subprocess.run(["verilator","--lint-only","--sv","-Wall","-Wno-fatal",str(root/"rtl/bank_port_router.sv")],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(a.evidence_dir/"verilator_lint.log").write_text(p.stdout,encoding="utf-8")
if v.returncode or p.returncode:raise SystemExit(1)
print("PASS: bank_port_router Verilator RTL lint")
