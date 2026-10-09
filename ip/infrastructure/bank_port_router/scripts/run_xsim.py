#!/usr/bin/env python3
from pathlib import Path
import argparse, os, subprocess
VIVADO=Path("/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin")
PASS="PASS: bank_port_router verification cases=11"
def logged(cmd,cwd,log):
  p=subprocess.run(cmd,cwd=cwd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  log.write_text(p.stdout,encoding="utf-8")
  if p.returncode: raise RuntimeError(f"command failed: {' '.join(map(str,cmd))}")
def main():
  ap=argparse.ArgumentParser();ap.add_argument("--work-dir",required=True,type=Path);ap.add_argument("--evidence-dir",required=True,type=Path);a=ap.parse_args()
  root=Path(__file__).resolve().parents[1];work=a.work_dir.resolve();ev=a.evidence_dir.resolve()
  if work.exists():raise RuntimeError(f"fresh work directory required: {work}")
  work.mkdir(parents=True);ev.mkdir(parents=True,exist_ok=True)
  logged([str(VIVADO/"xvlog"),"--sv",str(root/"rtl/bank_port_router.sv"),str(root/"tb/tb_bank_port_router.sv")],work,ev/"xvlog.log")
  logged([str(VIVADO/"xelab"),"tb_bank_port_router","-s","bank_port_router_sim"],work,ev/"xelab.log")
  env=os.environ.copy();env["LD_LIBRARY_PATH"]="/media/admin1/backup/tools/Xilinx/2025.2/Vivado/lib/lnx64.o"
  p=subprocess.Popen([str(work/"xsim.dir/bank_port_router_sim/xsimk")],cwd=work,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
  assert p.stdin is not None and p.stdout is not None
  lines=[]
  def until(marker):
    while True:
      line=p.stdout.readline()
      if not line:raise RuntimeError(f"XSIM ended before {marker}")
      lines.append(line)
      if marker in line:return
  until("=elaboration-done");p.stdin.write("-exec-run\n");p.stdin.flush();until('reason="run-complete"')
  p.stdin.write("-exec-continue\n");p.stdin.flush();until('reason="finish"');p.stdin.write("-gdb-exit\n");p.stdin.flush();lines.append(p.communicate(timeout=10)[0])
  transcript="".join(lines);(ev/"xsim_direct.log").write_text(transcript,encoding="utf-8")
  if p.returncode or transcript.count(f'@"{PASS}\\n"')!=1:raise RuntimeError("exact PASS missing")
  print(PASS)
if __name__=="__main__":main()
