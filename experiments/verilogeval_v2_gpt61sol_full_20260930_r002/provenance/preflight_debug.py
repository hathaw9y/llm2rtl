#!/usr/bin/env python3
import hashlib,json,shutil,subprocess,time
from pathlib import Path
root=Path(__file__).resolve().parent
d=root/'preflight_debug'
d.mkdir(exist_ok=False)
for name in ['dev_check.py','smoke_environment.py']:shutil.copy2(root/name,d/name)
bad="module TopModule(input logic clk, input logic d, output logic q);\nalways_ff @(posedge clk) q <= ~d;\nendmodule\n"
(d/'candidate.sv').write_text(bad)
(d/'candidate_initial.sv').write_text(bad)
(d/'dev_tb.sv').write_text("""`timescale 1ns/1ps
module dev_tb;
logic clk=0,d=0; wire q;
TopModule dut(.clk(clk),.d(d),.q(q));
initial begin
 #2; clk=1; #1; if(q !== 0) $fatal(1,"Expected sampled d=0");
 clk=0; d=1; #2; clk=1; #1; if(q !== 1) $fatal(1,"Expected sampled d=1");
 $display("PASS: debug preflight"); $finish;
end
initial begin #100; $fatal(1,"Timeout"); end
endmodule
""")
prompt="""This is a tooling/debugging preflight using GPT-6.1 Sol, not an official benchmark task. Use one Agent, no delegation, no browsing, work ONLY in this directory. Do not read other experiments or official benchmarks.
The specification is: TopModule has scalar clk,d,q ports and q captures d at each positive clock edge, holding between edges. No reset or initialization is specified. A deliberately faulty candidate.sv, immutable candidate_initial.sv and self-checking dev_tb.sv have been provided.
First run python3 smoke_environment.py. Then BEFORE ANY RTL EDIT run python3 dev_check.py --label initial on the provided faulty candidate. Read its real failure log. Debug candidate.sv against the specification, preserving initial and testbench, save candidate_revision_1.sv, and run python3 dev_check.py --label revision_1. Do not weaken the testbench or manually alter helper evidence. Use at most 3 RTL revisions and keep evidence. Write worker_report.json with revision_count and checks, then finish. Do not edit the helpers. Official feedback is unavailable.
"""
(d/'prompt.txt').write_text(prompt)
args=['codex','exec','--ignore-user-config','--ephemeral','--skip-git-repo-check','--sandbox','workspace-write','--model','gpt-6.1-sol','-c','features.multi_agent=false','-c','web_search="disabled"','--json','-C',str(d),'--output-last-message',str(d/'final_message.txt'),'-']
start=time.time()
with (d/'events.jsonl').open('w') as out,(d/'cli_stderr.log').open('w') as err:
 p=subprocess.run(args,input=prompt,text=True,stdout=out,stderr=err,cwd=d,timeout=300)
checks=[json.loads(line) for line in (d/'dev_checks.jsonl').read_text().splitlines()]
assert p.returncode==0
assert checks[0]['status']=='simulation_failed'
assert checks[-1]['status']=='passed'
assert checks[0]['source_sha256']!=checks[-1]['source_sha256']
assert hashlib.sha256((d/'candidate_initial.sv').read_bytes()).hexdigest()==hashlib.sha256(bad.encode()).hexdigest()
assert json.loads((d/'environment_smoke.json').read_text())['status']=='passed'
report={'status':'passed','model':'gpt-6.1-sol','scope':'Synthetic debugging preflight excluded from benchmark score','seconds':time.time()-start,'initial_check':checks[0]['status'],'final_check':checks[-1]['status'],'check_count':len(checks),'worker_report':json.loads((d/'worker_report.json').read_text())}
(d/'preflight_result.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
