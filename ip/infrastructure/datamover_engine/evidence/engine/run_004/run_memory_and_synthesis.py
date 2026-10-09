#!/usr/bin/env python3
import json, re, subprocess, sys, tempfile
from pathlib import Path
RUN=Path(__file__).resolve().parent
SNAP=RUN/'source_snapshot'
results=[]
def execute(command,work,path):
 with path.open('w') as out:
  result=subprocess.run(command,cwd=work,stdout=out,stderr=subprocess.STDOUT,timeout=300)
 return result.returncode
out=RUN/'memory_simulation';out.mkdir(exist_ok=False)
with tempfile.TemporaryDirectory(prefix='datamover-memory-') as folder:
 work=Path(folder)
 code=execute(['xvlog','-sv',str(SNAP/'rtl/bram_bank.sv'),str(SNAP/'rtl/uram_bank.sv'),str(SNAP/'tb/tb_memory_banks.sv')],work,out/'compile.txt')
 if code:raise SystemExit('memory compile failed')
 code=execute(['xelab','tb_memory_banks','-L','xpm','-s','memory_sim','-timescale','1ns/1ps'],work,out/'elaborate.txt')
 if code:raise SystemExit('memory elaborate failed')
 code=execute([sys.executable,str(SNAP/'scripts/run_xsimk.py'),str(work/'xsim.dir/memory_sim/xsimk'),'PASS: memory bank XPM functional verification'],work,out/'simulation.txt')
 raw=(out/'simulation.txt').read_text()
 messages=''.join(json.loads(line[1:]) for line in raw.splitlines() if line.startswith('@"'))
 (out/'program_output.txt').write_text(messages)
 passed=code==0 and bool(re.search(r'^PASS: memory bank XPM functional verification$',messages,re.M)) and 'CHECK_FAILED' not in raw and 'Fatal:' not in raw
 result={'stage':'memory_xsim','exit':code,'pass_marker':passed,'expected_invalid_access_diagnostics':raw.count('address out of range:')}
 results.append(result)
 (RUN/'memory_and_synthesis_results.json').write_text(json.dumps(results,indent=2)+'\n')
 print(result,flush=True)
 if not passed or result['expected_invalid_access_diagnostics']!=6:raise SystemExit('memory verification failed')
for top,width in [('datamover_engine',64),('datamover_engine',128),('bram_bank',0),('uram_bank',0)]:
 name=f'{top}_{width}' if width else top
 out=RUN/'synthesis'/name;out.mkdir(parents=True,exist_ok=False)
 with tempfile.TemporaryDirectory(prefix='datamover-ooc-') as folder:
  code=execute(['vivado','-mode','batch','-nojournal','-nolog','-source',str(RUN/'run_ooc.tcl'),'-tclargs',str(SNAP/'rtl'),str(out),top,str(width)],Path(folder),out/'tool_output.txt')
 output=(out/'tool_output.txt').read_text()
 marker=bool(re.search(r'^DATAMOVER_CURRENT_SOURCE_OOC_SYNTHESIS_COMPLETE$',output,re.M))
 result={'stage':'ooc_synthesis','top':top,'dma_width':width,'exit':code,'completion_marker':marker,'reports_complete':all((out/name).exists() for name in ['mapping.txt','timing_summary.rpt','utilization.rpt','drc.rpt','methodology.rpt','exceptions.rpt'])}
 results.append(result)
 (RUN/'memory_and_synthesis_results.json').write_text(json.dumps(results,indent=2)+'\n')
 print(result,flush=True)
 if code or not marker or not result['reports_complete']:raise SystemExit(1)
