#!/usr/bin/env python3
from pathlib import Path
import argparse,os,subprocess
V=Path("/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin");PASS="PASS: bank_sparse_router verification cases=11"
def logged(c,w,l):
 p=subprocess.run(c,cwd=w,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);l.write_text(p.stdout,encoding="utf-8")
 if p.returncode:raise RuntimeError(f"command failed: {' '.join(map(str,c))}")
def main():
 ap=argparse.ArgumentParser();ap.add_argument("--work-dir",type=Path,required=True);ap.add_argument("--evidence-dir",type=Path,required=True);a=ap.parse_args();r=Path(__file__).resolve().parents[1];w=a.work_dir.resolve();e=a.evidence_dir.resolve()
 if w.exists():raise RuntimeError(f"fresh work required: {w}")
 w.mkdir(parents=True);e.mkdir(parents=True,exist_ok=True);src=[r/"rtl/bank_config_pkg.sv",r/"rtl/bank_sparse_router.sv",r/"tb/tb_bank_sparse_router.sv"]
 logged([str(V/"xvlog"),"--sv",*map(str,src)],w,e/"xvlog.log");logged([str(V/"xelab"),"tb_bank_sparse_router","-s","bank_sparse_router_sim"],w,e/"xelab.log")
 env=os.environ.copy();env["LD_LIBRARY_PATH"]="/media/admin1/backup/tools/Xilinx/2025.2/Vivado/lib/lnx64.o";p=subprocess.Popen([str(w/"xsim.dir/bank_sparse_router_sim/xsimk")],cwd=w,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1);lines=[]
 def until(m):
  while True:
   x=p.stdout.readline()
   if not x:raise RuntimeError(f"XSIM ended before {m}")
   lines.append(x)
   if m in x:return
 until("=elaboration-done");p.stdin.write("-exec-run\n");p.stdin.flush();until('reason="run-complete"');p.stdin.write("-exec-continue\n");p.stdin.flush();until('reason="finish"');p.stdin.write("-gdb-exit\n");p.stdin.flush();lines.append(p.communicate(timeout=10)[0]);t="".join(lines);(e/"xsim_direct.log").write_text(t,encoding="utf-8")
 if p.returncode or t.count(f'@"{PASS}\\n"')!=1:raise RuntimeError("exact PASS missing")
 print(PASS)
if __name__=="__main__":main()
