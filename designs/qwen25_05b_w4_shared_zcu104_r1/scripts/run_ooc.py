#!/usr/bin/env python3
"""Snapshot exact sources/ROMs before Vivado; preserve scoped evidence on failure."""
import argparse,hashlib,json,os,shutil,subprocess,time
from pathlib import Path
BASE=Path(__file__).resolve().parents[1];ROOT=BASE.parents[1]
VIVADO='/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin/vivado'
def main():
 p=argparse.ArgumentParser();p.add_argument('top');p.add_argument('out',type=Path);a=p.parse_args()
 a.out=a.out.resolve();a.out.mkdir(exist_ok=False,parents=True);src=a.out/'source';(src/'rtl').mkdir(parents=True)
 files=list((BASE/'rtl').glob('*.sv'))+list((BASE/'evidence/fp32_run001').glob('*.mem'))+[BASE/'scripts/executor_ooc.tcl']
 if a.top=='qwen_bank_fabric':files += [ROOT/'ip/infrastructure/datamover_engine/rtl'/n for n in ['bram_bank.sv','uram_bank.sv']]
 for f in files:
  dest=src/'rtl'/f.name if f.suffix=='.sv' else src/f.name;shutil.copyfile(f,dest)
 # Use immutable ROM copies even if the workspace changes during a long run.
 nl=src/'rtl/qwen_nonlinear_scalar.sv';text=nl.read_text()
 for f in (BASE/'evidence/fp32_run001').glob('*.mem'):
  text=text.replace('designs/qwen25_05b_w4_shared_zcu104_r1/evidence/fp32_run001/'+f.name,str(src/f.name))
 nl.write_text(text)
 manifest={'scope':'Module OOC only; registered input min0.300ns/max1.000ns,200MHz, no board timing or deployment claim.','top':a.top,'files':{str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}}
 shutil.copyfile(BASE/'hardware_profile.json',src/'hardware_profile.json')
 manifest['hardware_profile_sha256']=hashlib.sha256((src/'hardware_profile.json').read_bytes()).hexdigest()
 manifest['build_source_sha256']={str(f.relative_to(src)):hashlib.sha256(f.read_bytes()).hexdigest() for f in src.rglob('*') if f.is_file()}
 (a.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');started=time.monotonic()
 (a.out/'tmp').mkdir();environment=os.environ.copy();environment['TMPDIR']=str(a.out/'tmp')
 (a.out/'designs').symlink_to(ROOT/'designs',target_is_directory=True)
 with (a.out/'console.log').open('w') as log:
  r=subprocess.run([VIVADO,'-mode','batch','-nojournal','-log',str(a.out/'vivado.log'),'-source',str(src/'executor_ooc.tcl'),'-tclargs',str(src),str(a.out),a.top],cwd=a.out,env=environment,stdout=log,stderr=subprocess.STDOUT)
 (a.out/'invocation.json').write_text(json.dumps({'returncode':r.returncode,'seconds':time.monotonic()-started,'manifest_sha256':hashlib.sha256((a.out/'manifest.json').read_bytes()).hexdigest()},indent=2)+'\n')
 print(a.top,r.returncode,(a.out/'result.txt').read_text() if (a.out/'result.txt').exists() else 'No routed result',flush=True)
 raise SystemExit(r.returncode)
if __name__=='__main__':main()
