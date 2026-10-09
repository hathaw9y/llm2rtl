#!/usr/bin/env python3
import os,subprocess,sys
from pathlib import Path
w=Path(sys.argv[1]).resolve();log=Path(sys.argv[2]).resolve();env=os.environ.copy()
env["LD_LIBRARY_PATH"]="/media/admin1/backup/tools/Xilinx/2025.2/Vivado/lib/lnx64.o"
p=subprocess.Popen([str(w/"xsim.dir/sparse_isa_dispatcher_sim/xsimk")],cwd=w,env=env,
 stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
lines=[]
def until(m):
 while True:
  x=p.stdout.readline()
  if not x: raise RuntimeError(f"XSIM ended before {m}")
  lines.append(x)
  if m in x:return
until("=elaboration-done");p.stdin.write("-exec-run\n");p.stdin.flush();until('reason="run-complete"')
p.stdin.write("-exec-continue\n");p.stdin.flush();until('reason="finish"');p.stdin.write("-gdb-exit\n");p.stdin.flush()
tail,_=p.communicate(timeout=20);lines.append(tail);text="".join(lines);log.write_text(text,encoding="utf-8")
if p.returncode or "SPARSE_ISA_DISPATCHER_XSIM_PASS" not in text:raise RuntimeError("XSIM FAIL")
print("SPARSE_ISA_DISPATCHER_XSIM_PASS")

