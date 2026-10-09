#!/usr/bin/env python3
"""Finish a reset-corrected build; every stage must pass before publication."""
import json,subprocess,sys,time
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
BACKUP=Path('/media/admin1/backup/llm2rtl-builds')/BASE.name
def run(script,*args):
 print('START '+script,flush=True)
 subprocess.run([sys.executable,str(BASE/'scripts'/script)]+[str(a) for a in args],check=True)
def main():
 build=BACKUP/'board_200mhz_build_run007';last=0
 while not (build/'invocation.json').exists():
  if time.monotonic()-last>=45:
   print('WAIT board build007: '+(build/'console.log').read_text(errors='replace').splitlines()[-1],flush=True);last=time.monotonic()
  time.sleep(5)
 result=json.loads((build/'invocation.json').read_text())
 if result['returncode']!=0:raise RuntimeError('Corrected board build failed; no artifact publication')
 audit=BACKUP/'board_200mhz_audit_run002'
 run('audit_board.py',build,audit)
 run('check_board_reset.py',build/'qwen.hwh')
 bsp=BASE/'releases/sd_bsp_run004';firmware=BASE/'releases/baremetal_sd_run007'
 run('build_sd_bsp.py',build/'qwen.xsa',bsp)
 run('build_baremetal.py',BACKUP/'board_data_run003',firmware,'--sd-bsp',bsp)
 handoff=BACKUP/'board_handoff_200mhz_run003'
 run('package_handoff.py','--build',build,'--audit',audit,'--data',BACKUP/'board_data_run003','--firmware',firmware,'--out',handoff)
 host=BASE/'releases/qwen_host_sd_200mhz_run003'
 run('package_host.py','--handoff',handoff,'--sd-firmware',firmware,'--out',host)
 subprocess.run([sys.executable,str(host/'host.py'),'verify'],check=True)
 run('package_host_patch.py',BASE/'releases/qwen_host_sd_200mhz_run002',host,BASE/'releases/qwen_sd_reset_patch_run001')
 report={'status':'prepared_reset_corrected_SD_handoff_no_physical_acceptance','build':str(build),'audit':str(audit),'firmware':str(firmware),'host':str(host),'physical_board_model_pass':False}
 (BASE/'evidence/reset_corrected_handoff_run003.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
