import sys,json,hashlib,subprocess,time,concurrent.futures
from pathlib import Path
D=Path(__file__).resolve().parents[4];kind,wanted=sys.argv[1:3];E=Path(__file__).resolve().parent/kind;E.mkdir(exist_ok=True)
if kind=='gemm':
 rtl=['w8a8_fp32_pkg.sv','w8a8_fp32_mul.sv','fp32_bf16_epilogue.sv','int8_dot_core.sv','smollm2_int8_gemm_executor.sv'];tbs={'normal':'executor_tb','stress':'executor_stress_tb'};vec='executor_vectors'
 names=['golden_prefill32_down_K1536','direct_M17_N17_K1536','direct_QK_M17_L33_scale_groups','direct_PV_L1024_INT32_max','direct_QK_L1_padded16','direct_PV_L1_tail','direct_combined_scale_underflow_negzero','direct_QK_L1024_cache_end','direct_m_start31_N1']
 tasks=[('normal',n,[]) for n in names]+[('normal','golden_warm_decode33_ATTN_SCORE_INT8',['+OLD_C=1','+RESET_PROBE=1','+REPEATS=2']),('stress','golden_prefill32_Q_K576',['+FAULT=0']),('stress','golden_prefill32_ATTN_SCORE_INT8',['+FAULT=0']),('stress','direct_m_start31_N1',['+FAULT=5']),('stress','direct_M17_N17_K1536',['+FAULT=15'])]
else:
 assert kind=='quantization';rtl=['w8a8_fp32_pkg.sv','w8a8_fp32_mul.sv','w8a8_fp32_div4.sv','w8a8_quant_lane4.sv','w8a8_dequant_lane4.sv','smollm2_quantization_executor.sv'];tbs={'normal':'quant_executor_tb','fault':'quant_executor_fault_tb','repeat':'quant_executor_repeat_tb'};vec='quant_executor_vectors'
 names=['direct_A17_mstart15_K1536','direct_P32_L1024_max_capacity','direct_K1_layer29_prefix32_double_round','direct_V17_layer29_prefix32_groups','direct_DQ32_all_lanes_unused_nonfinite','direct_DQ1_signed_zero','direct_P1_L1_all_negative','direct_P1_L17_masked_nonfinite','direct_A16_subnormal_K576','direct_K16_layer0_quotient_overflow']
 tasks=[('normal',n,[]) for n in names]+[('fault','direct_K1_layer29_prefix32_double_round',['+FAULT=1']),('fault','direct_DQ1_signed_zero',['+FAULT=18']),('fault','direct_P1_L1_all_negative',['+FAULT=17'])]+[('repeat',n,['+RESET_PROBE='+str(i)]) for n in ['direct_A1_context_K576','direct_DQ1_signed_zero'] for i in [2,3]]
files=[D/'rtl'/n for n in rtl]+[D/'tb'/(n+'.sv') for n in tbs.values()];hashes=lambda:{str(p.relative_to(D)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files};before=hashes();assert before['rtl/'+rtl[-1]]==wanted
compiles=[]
for k,tb in tbs.items():
 cmd=['iverilog','-g2012','-s',tb,'-o',str(E/('audit_'+k+'_sim'))]+[str(D/'rtl'/n) for n in rtl]+[str(D/'tb'/(tb+'.sv'))];p=subprocess.run(cmd,text=True,capture_output=True);(E/('audit_'+k+'_compile.log')).write_text(p.stdout+p.stderr);assert p.returncode==0;compiles.append({'command':cmd,'exit_code':0})
def run(t):
 k,n,args=t;cmd=['vvp',str(E/('audit_'+k+'_sim')),'+CASE='+str(D/'tb'/vec/n)]+args;start=time.monotonic();p=subprocess.run(cmd,text=True,capture_output=True,timeout=600);out=p.stdout+p.stderr;log=E/('audit_'+k+'_'+n+''.join(a.replace('+','_').replace('=','_') for a in args)+'.log');log.write_text(out);markers=[l for l in out.splitlines() if l.startswith(('EXECUTOR_PASS ','QUANT_EXECUTOR_PASS ','QUANT_EXECUTOR_FAULT_PASS ','QUANT_EXECUTOR_REPEAT_PASS '))];assert p.returncode==0 and markers,(t,out);print(n,args,markers,flush=True);return {'test_kind':k,'case':n,'args':args,'command':cmd,'exit_code':0,'seconds':time.monotonic()-start,'log':str(log.relative_to(D)),'markers':markers}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:results=list(pool.map(run,tasks))
after=hashes();assert before==after
report={'status':'FUNCTIONAL_PASS','source_hashes_before':before,'source_hashes_after':after,'compiles':compiles,'cases':results,'oracle':'Unmodified approved golden fixtures; fixture oracle independently rederived in prior audit with same fixturemanifest hashes','fixture_manifest_sha256':hashlib.sha256((D/'tb'/vec/'manifest.json').read_bytes()).hexdigest()}
(E/'replay_results.json').write_text(json.dumps(report,indent=2)+'\n');print('RETRY_INDEPENDENT_FUNCTIONAL_PASS',kind,wanted,flush=True)
