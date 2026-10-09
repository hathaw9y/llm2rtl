#!/usr/bin/env python3
"""Adapt read-only positive DDR environment to real-ISA projection coverage negatives."""
import pathlib,re,json,hashlib
H=pathlib.Path(__file__).resolve().parent;D=H.parents[1]
base=D/'evidence/independent_fabric_numerical/prepared/projection_fragments';P=D/'tb/fabric_vectors/projection_fragments'
source=base/'audit_fabric_tb.sv';raw=source.read_text();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for case in ['missing_last_tile','duplicate_first_tile']:
 out=H/('projection_negative_'+case);out.mkdir(exist_ok=True)
 for f in base.glob('*.bytehex'):(out/f.name).write_bytes(f.read_bytes())
 tb=raw.replace('module audit_fabric_tb;','module audit_projection_negative_tb;').replace('MAX_BYTES=36864, STAGES=3','MAX_BYTES=36864, STAGES=4').replace(str(base),str(out))
 tb=tb.replace('integer witness_b15_overlap=0,witness_b3_active_writes=0;','integer witness_b15_overlap=0,witness_b3_active_writes=0; bit expect_reject=0;')
 tb=tb.replace('if(error||(|dma_faulted))$fatal', 'if((error&&!expect_reject)||(|dma_faulted))$fatal')
 tb=tb.replace('  if(cmd_load_hold &&', '  if(m_axis_s2mm_cmd_tvalid||m_axis_s2mm_tvalid)$fatal(1,"partial GEMMprojection issued external STORE");\n  if(cmd_load_hold &&')
 files=[P/(case+f'_program_{s}.hex') for s in range(3)]+[P/(case+'_store.hex')]
 assignments=[]
 for stage,f in enumerate(files):
  words=[x.strip() for x in f.read_text().splitlines() if x.strip()]
  assert len(words)<=16
  for idx in range(16):assignments.append(f"programs[{stage}][{idx}]=128'h{words[idx] if idx<len(words) else '0'*32};")
 tb=re.sub(r"programs\[\d+\]\[\d+\]=128'h[0-9a-f]+;\n",'',tb)
 tb=tb.replace(' repeat(8)@(negedge clk);resetn=1;', '\n'.join(assignments)+'\n repeat(8)@(negedge clk);resetn=1;')
 tb=tb.replace('  wait(start_ready===1);@(negedge clk);start=1;', '  expect_reject=(stage==STAGES-1);wait(start_ready===1);@(negedge clk);start=1;')
 tb=tb.replace('  @(negedge clk);start=0;wait(done===1);\n  if(busy||error)$fatal(1,"done/error mismatch");', '  @(negedge clk);start=0;\n  if(expect_reject)begin wait(error===1 && busy===0);if(error_code!=4||dma_faulted!=0)$fatal(1,"partialprojection wrongerror %h",error_code);end\n  else begin wait(done===1);if(busy||error)$fatal(1,"done/error mismatch");end')
 tb=re.sub(r' for\(integer a=0;a<ASSETS;a=a\+1\)if\(asset_output\[a\]\).*?\n','',tb)
 tb=tb.replace('if(lw!=19||sw!=1)', 'if(lw!=19||sw!=0)').replace('command_stalls==0||load_bubbles==0||store_stalls==0||status_delay_cycles==0','command_stalls==0||load_bubbles==0||status_delay_cycles==0')
 tb=tb.replace('PASS_INDEPENDENT_FABRIC_NUMERICAL_projection_fragments','AUDIT_PROJECTION_NEGATIVE_PASS_'+case)
 (out/'audit_projection_negative_tb.sv').write_text(tb)
 (out/'prepared_environment_provenance.json').write_text(json.dumps({'scope':'PREPARED_ONLY_NO_RTL_PROOF; external DDRBFM reused read-only, actual DUT must instantiate frozen physical children','source_environment':str(source),'source_environment_sha256':sha(source),'program_pins':{str(f):sha(f) for f in files},'assets':{str(f):sha(f) for f in out.glob('*.bytehex')},'expected':'19 real DMA LOAD commands, actual quant+8unique GEMM N64 tiles across3START; finalSTORE128 rejects04 before any vendorSTORE/native read because missing bytes1024..1151. duplicate_first executes extra nstart0 without filling finaltile.'},indent=2)+'\n')
 print(out/'audit_projection_negative_tb.sv')
