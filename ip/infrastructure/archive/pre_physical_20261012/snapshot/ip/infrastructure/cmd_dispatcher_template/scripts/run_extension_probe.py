#!/usr/bin/env python3
"""Run a marker-only arbitrary role command extension with native XPM banks."""
import argparse
from pathlib import Path
from native_test_support import BASE,VIVADO,logged,manifest,materialize_banks,snapshot_run,verify_identity
PASS_MARKER='PASS: marker-only arbitrary-role native extension probe'
def main():
    p=argparse.ArgumentParser();p.add_argument('--source',required=True,type=Path);p.add_argument('--work-dir',required=True,type=Path);p.add_argument('--evidence-dir',required=True,type=Path);a=p.parse_args()
    work=a.work_dir.resolve();evidence=a.evidence_dir.resolve();work.mkdir(parents=True,exist_ok=False);evidence.mkdir(parents=True,exist_ok=False)
    extended=work/'cmd_dispatcher_template_extended.sv'
    logged(['python3',BASE/'scripts/generate_extension_probe.py','--source',a.source.resolve(),'--output',extended],work,evidence/'generate.log')
    sources=materialize_banks(work,True)+[extended,BASE/'tb/tb_cmd_dispatcher_extension_probe.sv']
    identity=manifest([*sources,a.source.resolve()],evidence,'native_controller_generated_extension')
    logged([VIVADO/'xvlog','--sv',*sources],work,evidence/'xvlog.log')
    name='native_controller_extension_sim'
    logged([VIVADO/'xelab','tb_cmd_dispatcher_extension_probe','-L','xpm','-s',name,'-timescale','1ns/1ps'],work,evidence/'xelab.log')
    snapshot_run(work/'xsim.dir'/name/'xsimk',work,evidence/'xsim.log',PASS_MARKER)
    verify_identity(identity);print(PASS_MARKER)
if __name__=='__main__':main()
