#!/usr/bin/env python3
"""Source-identified controller + native XPM banks, command latency 1 and 2."""
import argparse
from pathlib import Path
from native_test_support import BASE,VIVADO,logged,manifest,materialize_banks,snapshot_run,verify_identity
PASS_MARKER='PASS: cmd_dispatcher_template native controller verification'
def main():
    p=argparse.ArgumentParser();p.add_argument('--work-dir',required=True,type=Path);p.add_argument('--evidence-dir',required=True,type=Path);a=p.parse_args()
    work=a.work_dir.resolve();evidence=a.evidence_dir.resolve()
    work.mkdir(parents=True,exist_ok=False);evidence.mkdir(parents=True,exist_ok=False)
    sources=materialize_banks(work)+[BASE/'rtl/cmd_dispatcher_template.sv',BASE/'tb/tb_cmd_dispatcher_template.sv']
    identity=manifest(sources,evidence,'native_controller_xsim')
    logged([VIVADO/'xvlog','--sv',*sources],work,evidence/'xvlog.log')
    for latency,capability in [(1,0),(2,0),(2,1)]:
        label=f'lat{latency}_cap{capability}';snapshot=f'native_controller_{label}'
        logged([VIVADO/'xelab','tb_cmd_dispatcher_template','-L','xpm','-generic_top',f'CMD_READ_LATENCY={latency}','-generic_top',f'CAPABILITY_CASE={capability}','-s',snapshot,'-timescale','1ns/1ps'],work,evidence/f'xelab_{label}.log')
        snapshot_run(work/'xsim.dir'/snapshot/'xsimk',work,evidence/f'xsim_{label}.log',PASS_MARKER)
    verify_identity(identity)
    print(PASS_MARKER)
if __name__=='__main__':main()
