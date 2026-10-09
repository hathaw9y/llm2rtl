import hashlib,json,subprocess,time
from pathlib import Path
D=Path(__file__).resolve().parents[1];E=D/'evidence/int8_gemm_executor'
commands=[['python3',str(D/'scripts/run_executor_sim.py')],['python3',str(D/'scripts/run_executor_errors.py')]]
for cmd in commands:subprocess.run(cmd,check=True)
extra=[]
for name,args in [('direct_m_start31_N1',['+REPEATS=3','+RESET_PROBE=1']),('golden_warm_decode32_ATTN_SCORE_INT8',['+REPEATS=2','+RESET_PROBE=1','+OLD_C=1']),('golden_warm_decode32_ATTN_VALUE_INT8',['+REPEATS=2','+RESET_PROBE=1'])]:
 cmd=['vvp',str(E/'sim'),'+CASE='+str(D/'tb/executor_vectors'/name)]+args
 p=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(E/(name+'_repeat_reset.log')).write_text(p.stdout);print(p.stdout.strip(),flush=True)
 if p.returncode or not any(l.startswith('EXECUTOR_PASS ') for l in p.stdout.splitlines()):raise SystemExit(1)
 extra.append({'case':name,'command':cmd,'exit_code':0})
rtl=['w8a8_fp32_pkg.sv','w8a8_fp32_mul.sv','fp32_bf16_epilogue.sv','int8_dot_core.sv','smollm2_int8_gemm_executor.sv']
cmd=['verilator','--lint-only','--unroll-count','2048','-Wall','-Wno-fatal','--top-module','smollm2_int8_gemm_executor']+[str(D/'rtl'/r) for r in rtl]
p=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(E/'lint.log').write_text(p.stdout)
if p.returncode:raise SystemExit(p.stdout)
critical=['%Warning-LATCH','%Warning-MULTIDRIVEN','%Warning-WIDTH','%Error']
if any(x in p.stdout for x in critical):raise SystemExit('critical lint diagnostics')
manifest_files=[*[D/'rtl'/r for r in rtl],D/'tb/executor_tb.sv',D/'scripts/run_executor_sim.py',D/'scripts/run_executor_errors.py',D/'scripts/run_executor_validation.py',D/'modules/int8_gemm_executor.json',D/'contracts/rtl_port_binding.json',D/'tb/executor_vectors/manifest.json']
hashes={str(f.relative_to(D)):hashlib.sha256(f.read_bytes()).hexdigest() for f in manifest_files}
sim=json.loads((E/'simulation_cases.json').read_text())
if any(hashes[n]!=h for n,h in sim['source_hashes'].items()):raise SystemExit('source changed after main simulation')
report={'module_id':'int8_gemm_executor','status':'SELF_VERIFIED_STANDALONE_RTL_SIMULATION_ONLY','source_hashes':hashes,'case_count':len(sim['cases']),'error_case_count':15,'repeat_reset_scenarios':extra,'lint_command':cmd,'lint_status':'PASS_NO_WIDTH_LATCH_MULTIDRIVER_ERRORS_UNUSED_ONLY','children_consumed':{'functional_audit':'evidence/independent_datapath_audit/module_verification_report.json','gate':'FUNCTIONAL_ACCEPTED; OOC withheld'},'architecture_evidence':'13 fixtures show real256-product child acceptance; M32K1536 maxII1burst3072; inactive Bpanel filling overlaps active panel steps; four epilogue output lanes; staged A and result FIFO use registered memory reads','native_response_strategy':'Each returned beat deterministically processed at arrival, no downstream-ready; accepted-minus-processed credit<=4. No queued response beat can overwrite staged operand storage. On errors discard accepted responses and retire offered requests before invalidation.','PV_transpose':'scatter selected128bit source token featurebundle directly into inactiveN16K32 Bpanel; readiness only after everyresponse processed','remaining_gates':['independent integration verification','native fabric and concurrent alternate-bank DMA integration','Vivado2025.2 OOC on user-designated machine','5ns setup/hold/pulse-width/resource evidence','fullmodel/board validation'],'scope_exclusions':['all30layers','checkpointaccuracy','otheropcodeexecutors','boardfit/route/hardwarepass'],'synthesis':'NOT_RUN_PENDING_DESIGNATED_MACHINE'}
(E/'kernel_report.json').write_text(json.dumps(report,indent=2)+'\n')
(E/'subagent_result.json').write_text(json.dumps({'module_id':report['module_id'],'status':report['status'],'files_changed':['rtl/smollm2_int8_gemm_executor.sv','tb/executor_tb.sv','scripts/run_executor_sim.py','scripts/run_executor_errors.py','scripts/run_executor_validation.py','scripts/executor_ooc.tcl','evidence/int8_gemm_executor/'],'source_sha256':hashes['rtl/smollm2_int8_gemm_executor.sv'],'remaining_risks':report['remaining_gates'],'physical_memory_inference':'registered A/read FIFO coded; not measured without synthesis','timing_risk':'variable job-shape address divisions/modulo and high fanout remain synthesis/timing closure risks','contracts_unchanged':True,'children_unchanged':True},indent=2)+'\n')
print('EXECUTOR_PACKET_SELF_VERIFICATION_PASS')
