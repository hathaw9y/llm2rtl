#!/usr/bin/env python3
from pathlib import Path
import argparse,subprocess
ap=argparse.ArgumentParser();ap.add_argument("--evidence-dir",type=Path,required=True);a=ap.parse_args();r=Path(__file__).resolve().parents[1];a.evidence_dir.mkdir(parents=True,exist_ok=True)
v=subprocess.run(["verilator","--version"],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(a.evidence_dir/"verilator_version.log").write_text(v.stdout,encoding="utf-8")
p=subprocess.run(["verilator","--lint-only","--sv","-Wall","-Wno-fatal","--top-module","bank_sparse_router",str(r/"rtl/bank_config_pkg.sv"),str(r/"rtl/bank_sparse_router.sv")],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(a.evidence_dir/"verilator_lint.log").write_text(p.stdout,encoding="utf-8")
if v.returncode or p.returncode:raise SystemExit(1)
print("PASS: bank_sparse_router Verilator RTL lint")
