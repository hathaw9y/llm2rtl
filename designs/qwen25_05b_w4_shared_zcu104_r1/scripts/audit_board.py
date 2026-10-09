#!/usr/bin/env python3
"""Audit existing routed checkpoint; no source changes or physical board access."""
import argparse,hashlib,json,os,re,shutil,subprocess
from pathlib import Path
from check_board_reset import check as check_reset
BASE=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('build',type=Path);p.add_argument('out',type=Path);a=p.parse_args();a.build=a.build.resolve();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
 reset_wiring=check_reset(a.build/'qwen.hwh')
 shutil.copyfile(BASE/'scripts/audit_board.tcl',a.out/'audit_board.tcl');(a.out/'tmp').mkdir();env=os.environ.copy();env['TMPDIR']=str(a.out/'tmp')
 with (a.out/'console.log').open('w') as log:r=subprocess.run(['/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin/vivado','-mode','batch','-nojournal','-log',str(a.out/'vivado.log'),'-source',str(a.out/'audit_board.tcl'),'-tclargs',str(a.build),str(a.out)],cwd=a.out,env=env,stdout=log,stderr=subprocess.STDOUT)
 checks={}
 if r.returncode==0:
  text=(a.out/'timing_summary.rpt').read_text()
  for category in ['no_clock','unconstrained_internal_endpoints','multiple_clock','generated_clocks','loops','partial_input_delay','partial_output_delay','latch_loops']:
   matches=re.findall(r'checking '+re.escape(category)+r' \((\d+)\)',text)
   checks[category]={'reported_counts':[int(m) for m in matches],'passed':bool(matches) and all(int(m)==0 for m in matches)}
  for kind in ['Setup','Hold','PW']:
   matches=re.findall(r'^\s*'+kind+r'\s*:\s*(\d+)\s+Failing Endpoint.*?Worst Slack\s+([-+0-9.]+)ns',text,flags=re.M)
   checks[kind]={'clocks':[{'failing_endpoints':int(n),'worst_slack_ns':float(s)} for n,s in matches],'passed':bool(matches) and all(int(n)==0 and float(s)>=0 for n,s in matches)}
 passed=r.returncode==0 and all(c['passed'] for c in checks.values()) and bool(checks)
 report={'status':'passed_routed_200MHz_clock_timing_audit' if passed else 'failed_or_incomplete_routed_audit','returncode':r.returncode,'scope':'Routed static design only; no physical FPGA proof. PS dedicated I/O timing is governed by the matched board/PS preset.','routed_DCP_sha256':sha(a.build/'routed.dcp'),'audit_script_sha256':sha(a.out/'audit_board.tcl'),'checks':checks,'report_sha256':{n:sha(a.out/n) for n in ['clocks.rpt','timing_summary.rpt','drc.rpt','check_timing.rpt','audit_result.txt'] if (a.out/n).exists()}}
 report['exported_reset_wiring']=reset_wiring
 report['HWH_sha256']=sha(a.build/'qwen.hwh')
 (a.out/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status']);raise SystemExit(0 if passed else 1)
if __name__=='__main__':main()
