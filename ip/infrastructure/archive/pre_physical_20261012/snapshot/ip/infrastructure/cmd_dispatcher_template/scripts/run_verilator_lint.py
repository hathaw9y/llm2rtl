#!/usr/bin/env python3
import argparse
from pathlib import Path
from native_test_support import BASE,logged,sha
p=argparse.ArgumentParser();p.add_argument('--evidence-dir',required=True,type=Path);a=p.parse_args()
a.evidence_dir.mkdir(parents=True,exist_ok=False)
logged(['verilator','--version'],a.evidence_dir,a.evidence_dir/'version.log')
# Reserved instruction bits and USER hook operands are intentionally unused in the DMA-only template.
# Waive only that category; all other Wall diagnostics remain fatal.
logged(['verilator','--lint-only','--sv','-Wall','-Wno-UNUSED','--top-module','cmd_dispatcher_template',BASE/'rtl/cmd_dispatcher_template.sv'],a.evidence_dir,a.evidence_dir/'lint.log')
(a.evidence_dir/'source.sha256').write_text(sha(BASE/'rtl/cmd_dispatcher_template.sv')+'\n')
print('PASS: cmd_dispatcher_template Verilator RTL lint')
