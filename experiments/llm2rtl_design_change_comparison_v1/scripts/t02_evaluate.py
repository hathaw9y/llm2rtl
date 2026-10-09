#!/usr/bin/env python3
"""T02 independent layout gate. Adapter is required for candidate software evidence."""
import argparse,json,subprocess,sys,os,hashlib,time
from pathlib import Path
E=Path(__file__).resolve().parents[1]/'evaluator/t02'
sys.path.insert(0,str(E));from oracle import *
p=argparse.ArgumentParser();p.add_argument('--candidate-root',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--baseline-mode',action='store_true');p.add_argument('--split',choices=['public','hidden','all'],default='all');p.add_argument('--rtl',action='store_true');p.add_argument('--oracle-self-test',action='store_true');p.add_argument('--mutation',choices=['none','old-address','double-pack'],default='none');a=p.parse_args()
a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=True);a.candidate_root=a.candidate_root.resolve()
report={'candidate_root':str(a.candidate_root),'evaluator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'oracle_sha256':hashlib.sha256((E/'oracle.py').read_bytes()).hexdigest(),'tb_sha256':hashlib.sha256((E/'tb_t02.sv').read_bytes()).hexdigest(),'task':'T02','baseline_mode':a.baseline_mode,'mutation':a.mutation,'checks':[],'limitations':['Dense kernel only; attention runtime, full-model asset integration, PS C build, synthesis and board execution require separate gates.']}
if (a.candidate_root/'rtl').exists():design=a.candidate_root
else:design=a.candidate_root/'designs/smollm2_135m_bf16_zcu104_r1'
adapter=a.candidate_root/'t02_adapter.py'
def run(cmd,cwd,log):
 r=subprocess.run(cmd,cwd=cwd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=600)
 log.write_text(r.stdout)
 if r.returncode:raise RuntimeError(f'command failed ({r.returncode}): {log}')
 return r.stdout
def probe(req):
 r=subprocess.run([sys.executable,str(adapter)],input=json.dumps(req),text=True,capture_output=True,timeout=120)
 if r.returncode:raise RuntimeError(r.stderr)
 return json.loads(r.stdout)
def hex_words(path,bits,width=8):
 path.write_text(''.join(''.join(f'{v:04x}' for v in reversed(bits[i:i+width]+[0]*max(0,width-len(bits[i:i+width]))))+'\n' for i in range(0,len(bits),width)))
try:
 if a.oracle_self_test:
  for split in ['public','hidden']:
   for k,n,rows in raw_bits_cases(split):
    assert unpack(pack(rows),n,k)==rows
    assert unpack(pack(rows,True),n,k,True)==rows
   vs=list(vectors(split));w=next(x for x in vs if x['k']==64 and x['n']==7);rows=w['rows'];bits=pack(rows)
   assert unpack(bits,7,64,True)!=rows,'old address mutation survived'
   twice=pack([bits[i*64:(i+1)*64] for i in range(7)])
   assert unpack(twice,7,64)!=rows,'double packing mutation survived'
  report['checks'].append({'oracle_self_test':'PASS','old_address_rejected':True,'double_pack_rejected':True})
 else:
  if not adapter.exists() and not a.baseline_mode:raise RuntimeError('required candidate-root/t02_adapter.py is missing (see adapter_contract.md)')
 if a.rtl:
  rtl=(design/'rtl/smollm2_gemm_systolic_wide_executor.sv').read_text()
  # Positive control is evaluator-owned, never used to judge participant source.
  if a.oracle_self_test and not a.baseline_mode and a.mutation!='old-address':
   old="32'(weight_row_index_r) * 32'(k_total_r) +\n                                     32'(k_base_r)"
   new="(32'(k_base_r) >> 4) * 32'(n_tile_r) * 16 + 32'(weight_row_index_r) * 16"
   assert rtl.count(old)==1;rtl=rtl.replace(old,new)
  report['dut_sha256']=hashlib.sha256(rtl.encode()).hexdigest()
  report['source_path']=str(design/'rtl/smollm2_gemm_systolic_wide_executor.sv')
  report['control_source_changed']=bool(a.oracle_self_test and not a.baseline_mode and a.mutation!='old-address')
  (a.out/'dut.sv').write_text(rtl)
  bindir=Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin')
  env_script=bindir/'xvlog'
  run([str(env_script),'--sv',str(a.out/'dut.sv'),str(E/'tb_t02.sv')],a.out,a.out/'compile.log')
  run([str(bindir/'xelab'),'tb_t02','-s','t02_sim'],a.out,a.out/'elaborate.log')
 for split in (['public','hidden'] if a.split=='all' else [a.split]):
  # Arbitrary bit preservation is separate from finite arithmetic vectors.
  if adapter.exists() and not a.oracle_self_test:
   for k,n,rows in raw_bits_cases(split):
    bits=pack(rows,a.baseline_mode)
    result=probe({'op':'dense_tile','baseline_mode':a.baseline_mode,'n':n,'k':k,'rows':rows,'physical_bits':bits,'probe_k':[0,15,16 if k>16 else 15,k-1],'byte_base':4096,'tile_index':2})
    assert result['packed_bits']==bits,'offline packing differs'
    assert result['unpacked_rows']==rows,'candidate inverse differs'
    assert result['interpreted_rows']==rows,'interpreter physical dense load differs'
    assert result['layout_id']==(OLD if a.baseline_mode else NEW),'layout declaration'
    assert result['sha256']==digest(bits),'packed image hash'
    assert result['dma_offset_bytes']==4096+2*n*k*2 and result['dma_btt']==n*k*2,'DMA offset/BTT'
    assert result['gemm_tiles_weight_step_bytes']==n*k*2,'compressed descriptor weight step'
    embedding=[rows[0],rows[-1]]
    shared=probe({'op':'embedding_lm_head','baseline_mode':a.baseline_mode,'embedding_rows':embedding,'byte_base':0x100000,'reserved_end':0x400000})
    assert shared['embedding_lookup_rows']==embedding,'embedding lookup changed'
    assert shared['lm_head_physical_bits']==pack(embedding,a.baseline_mode),'LM head dense layout'
    assert shared['lm_head_interpreted_rows']==embedding,'LM head interpreter'
    assert shared['embedding_byte_base']==0x100000
    assert shared['lm_head_byte_base']+len(embedding)*k*2<=0x400000,'DDR bounds'
    if k>16 and not a.baseline_mode:assert shared['lm_head_byte_base']>=0x100000+len(embedding)*k*2,'LM head still aliases embeddings'
    report['checks'].append({'software_bits':f'{split}_k{k}_n{n}','status':'PASS'})
  for case in vectors(split):
   k,n,rows=case['k'],case['n'],case['rows'];m=min(7,len(case['probes']));probes=case['probes'][-m:]
   bits=pack(rows,a.baseline_mode)
   if a.mutation=='double-pack':bits=pack([bits[i*k:(i+1)*k] for i in range(n)],a.baseline_mode)
   expected=[rows[col][inner] for inner in probes for col in range(n)]
   folder=a.out/case['id'];folder.mkdir(exist_ok=True)
   act=[0]*((m+1)*k)
   for i,inner in enumerate(probes):act[(i+1)*k+inner]=0x3f80
   hex_words(folder/'act.hex',act);hex_words(folder/'weight.hex',bits);hex_words(folder/'expected.hex',expected,1)
   (folder/'case.json').write_text(json.dumps({'k':k,'n':n,'m':m,'probe_k':probes,'weight_sha256':digest(bits),'expected_bf16_sha256':digest(expected)}))
   if a.rtl:
    log=run([str(bindir/'xsim'),'t02_sim','-runall','-testplusarg',f'K={k}','-testplusarg',f'N={n}','-testplusarg',f'M={m}','-testplusarg',f'ACT={folder}/act.hex','-testplusarg',f'WEIGHT={folder}/weight.hex','-testplusarg',f'EXPECTED={folder}/expected.hex'],a.out,folder/'xsim.log')
    if 'T02_RTL_PASS' not in log:
     fatal=next((line.strip() for line in log.splitlines() if 'Fatal:' in line),'missing T02_RTL_PASS')
     raise AssertionError(f'RTL failed {case["id"]}: {fatal}; see {folder}/xsim.log')
    report['checks'].append({'rtl':case['id'],'status':'PASS','expected_bf16_sha256':digest(expected),'packed_weight_sha256':digest(bits)})
 report['status']='PASS'
 if not a.rtl:report['limitations'].append('RTL was not run.')
 if not adapter.exists():report['limitations'].append('Candidate software adapter was not run; baseline/software correctness not established.')
except Exception as exc:
 report['status']='FAIL';report['error']=str(exc)
finally:
 (a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
 (a.out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2));sys.exit(0 if report['status']=='PASS' else 1)
