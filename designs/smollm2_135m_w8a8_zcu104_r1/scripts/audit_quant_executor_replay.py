import hashlib,json,subprocess,time
from pathlib import Path
D=Path(__file__).resolve().parents[1]; E=D/'evidence/independent_quant_executor_audit';E.mkdir(exist_ok=True)
rtl=[D/'rtl'/x for x in ['w8a8_fp32_pkg.sv','w8a8_fp32_mul.sv','w8a8_fp32_div4.sv','w8a8_quant_lane4.sv','w8a8_dequant_lane4.sv','smollm2_quantization_executor.sv']]
tbs={kind:D/'tb'/('quant_executor'+suffix+'_tb.sv') for kind,suffix in [('normal',''),('fault','_fault'),('repeat','_repeat')]}
files=rtl+list(tbs.values()); hashes=lambda:{str(f.relative_to(D)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
before=hashes();assert before['rtl/smollm2_quantization_executor.sv']=='fa02a045c836090049818f765484d5f7be0f9f95f35d1edf4b60e976fb01d411'
records=[];compiles=[]
for kind,tb in tbs.items():
 cmd=['iverilog','-g2012','-s',tb.stem,'-o',str(E/('audit_'+kind+'_sim'))]+list(map(str,rtl))+[str(tb)]
 p=subprocess.run(cmd,capture_output=True,text=True);(E/('audit_'+kind+'_compile.log')).write_text(p.stdout+p.stderr);assert p.returncode==0
 compiles.append({'command':cmd,'exit_code':p.returncode})
normal=['direct_A17_mstart15_K1536','direct_P32_L1024_max_capacity','direct_K1_layer29_prefix32_double_round','direct_V17_layer29_prefix32_groups','direct_DQ32_all_lanes_unused_nonfinite','direct_DQ1_signed_zero','direct_P1_L1_all_negative','direct_P1_L17_masked_nonfinite','direct_A16_subnormal_K576','direct_K16_layer0_quotient_overflow']
tasks=[('normal',n,None) for n in normal]+[('fault','direct_K1_layer29_prefix32_double_round',1),('fault','direct_DQ1_signed_zero',18),('fault','direct_P1_L1_all_negative',17),('fault','direct_K1_layer29_prefix32_double_round',10),('fault','direct_DQ1_signed_zero',9)]+[('repeat',n,i) for n in ['direct_A1_context_K576','direct_DQ1_signed_zero'] for i in [2,3]]
for kind,n,arg in tasks:
 cmd=['vvp',str(E/('audit_'+kind+'_sim')),'+CASE='+str(D/'tb/quant_executor_vectors'/n)]
 if arg is not None:cmd.append(('+'+'FAULT' if kind=='fault' else '+RESET_PROBE')+'='+str(arg))
 start=time.monotonic();p=subprocess.run(cmd,capture_output=True,text=True,timeout=300);out=p.stdout+p.stderr;name='audit_'+kind+'_'+n+('' if arg is None else '_'+str(arg));(E/(name+'.log')).write_text(out)
 markers=[l for l in out.splitlines() if 'PASS' in l];assert p.returncode==0 and markers,(name,out)
 records.append({'kind':kind,'case':n,'argument':arg,'command':cmd,'exit_code':p.returncode,'elapsed_seconds':time.monotonic()-start,'markers':markers,'log':str((E/(name+'.log')).relative_to(D))})
 (E/'replay_results.json').write_text(json.dumps({'source_hashes_before':before,'compiles':compiles,'cases':records},indent=2)+'\n');print(name,markers,flush=True)
after=hashes();assert before==after
(E/'replay_results.json').write_text(json.dumps({'source_hashes_before':before,'source_hashes_after':after,'compiles':compiles,'cases':records,'status':'passed'},indent=2)+'\n')
