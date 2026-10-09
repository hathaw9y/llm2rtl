#!/usr/bin/env python3
import argparse,hashlib,json,os,shutil,subprocess,time
from pathlib import Path
BASE=Path(__file__).resolve().parents[1];ROOT=BASE.parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('out',type=Path);p.add_argument('--stage',choices=['validate','build'],default='build');a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);src=out/'source';(src/'rtl').mkdir(parents=True);(src/'common').mkdir()
 common=ROOT/'ip/infrastructure/datamover_engine/rtl';files=list(common.glob('*.sv'))+[ROOT/'ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv']
 for f in files:shutil.copyfile(f,src/'common'/f.name)
 for f in list((BASE/'rtl').glob('*.sv'))+list((BASE/'rtl').glob('*.v')):shutil.copyfile(f,src/'rtl'/f.name);files.append(f)
 shutil.copyfile(BASE/'hardware_profile.json',src/'hardware_profile.json');files.append(BASE/'hardware_profile.json')
 script=BASE/'scripts/build_board.tcl';shutil.copyfile(script,src/'build_board.tcl');files.append(script)
 # Freeze ROM paths in the source copy to immutable copies, without numeric change.
 roms=list((BASE/'evidence/fp32_run001').glob('*.mem'));(src/'rom').mkdir()
 for f in roms:shutil.copyfile(f,src/'rom'/f.name);files.append(f)
 nl=src/'rtl/qwen_nonlinear_scalar.sv';text=nl.read_text()
 for f in roms:text=text.replace('designs/qwen25_05b_w4_shared_zcu104_r1/evidence/fp32_run001/'+f.name,str(src/'rom'/f.name))
 nl.write_text(text)
 manifest={'scope':'ZCU104 routed artifact preparation. No user-board execution proof; numerical limitations remain separately reported.','clock_MHz':200,'part':'xczu7ev-ffvc1156-2-e','tool':'Vivado2025.2','original_sources_sha256':{str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files},'build_source_sha256':{str(f.relative_to(src)):hashlib.sha256(f.read_bytes()).hexdigest() for f in src.rglob('*') if f.is_file()},'stage':a.stage}
 (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');start=time.monotonic()
 # Keep Vivado's .Xil and temporary files off the nearly full root filesystem.
 (out/'tmp').mkdir();environment=os.environ.copy();environment['TMPDIR']=str(out/'tmp')
 with (out/'console.log').open('w') as log:r=subprocess.run(['/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin/vivado','-mode','batch','-nojournal','-log',str(out/'vivado.log'),'-source',str(src/'build_board.tcl'),'-tclargs',str(src),str(out),a.stage],cwd=out,env=environment,stdout=log,stderr=subprocess.STDOUT)
 (out/'invocation.json').write_text(json.dumps({'returncode':r.returncode,'seconds':time.monotonic()-start},indent=2)+'\n');print('board stage',a.stage,'returncode',r.returncode,flush=True);raise SystemExit(r.returncode)
if __name__=='__main__':main()
