#!/usr/bin/env python3
import os,subprocess
from pathlib import Path
w=Path('/tmp/datamover_engine_probe_final2.MLElWU')
log=Path('/home/shmin/llm2rtl/ip/infrastructure/datamover_engine/evidence/engine/run_001/independent_verification/probe_xsim_direct.log')
env=os.environ.copy();env['LD_LIBRARY_PATH']='/media/admin1/backup/tools/Xilinx/2025.2/Vivado/lib/lnx64.o'
p=subprocess.Popen([str(w/'xsim.dir/datamover_engine_probe_sim/xsimk')],cwd=w,env=env,
 stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
lines=[]
def until(marker):
 while True:
  line=p.stdout.readline()
  if not line: raise RuntimeError(f'XSIM ended before {marker}')
  lines.append(line)
  if marker in line:return
until('=elaboration-done');p.stdin.write('-exec-run\n');p.stdin.flush();until('reason="run-complete"')
p.stdin.write('-exec-continue\n');p.stdin.flush();until('reason="finish"');p.stdin.write('-gdb-exit\n');p.stdin.flush()
tail,_=p.communicate(timeout=20);lines.append(tail);text=''.join(lines);log.write_text(text,encoding='utf-8')
if p.returncode or 'DATAMOVER_ENGINE_INDEPENDENT_PROBE_PASS cases=3' not in text:raise RuntimeError('probe fail')
print('DATAMOVER_ENGINE_INDEPENDENT_PROBE_PASS cases=3')
