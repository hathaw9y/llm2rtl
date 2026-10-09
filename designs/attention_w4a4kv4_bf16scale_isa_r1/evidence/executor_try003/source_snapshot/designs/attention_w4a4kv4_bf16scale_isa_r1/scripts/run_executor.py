#!/usr/bin/env python3
"""Bounded scalar executor tests against source-identified full tensor vectors."""
import argparse,hashlib,json,shutil,subprocess,struct,sys
from pathlib import Path
BASE=Path(__file__).resolve().parents[1];ROOT=BASE.parents[1]
sys.path.insert(0,str(ROOT/'designs/attention_int4_noscale_zcu104_r1/scripts'))
from xsim_runtime import snapshot_run,VIVADO
QUANT=ROOT/'designs/attention_int4_noscale_zcu104_r1/rtl/attention_int4_quantizer.sv'
SOURCES=[BASE/'rtl'/n for n in ['attention_tensor_pkg.sv','attention_fp32_alu.sv','attention_fp32_exp_rom.sv','attention_exp_neg.sv']]+[QUANT,BASE/'rtl/attention_tensor_executor.sv']
PROFILES=['prefill','last_token','odd_head','noncausal_mask','all_masked','zero','gentle','max_tokens','max_row']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(command,cwd,log):
    if log.exists():raise RuntimeError('Do not replace '+str(log))
    with log.open('w')as f:p=subprocess.run(list(map(str,command)),cwd=cwd,stdout=f,stderr=subprocess.STDOUT,timeout=1200)
    log.with_suffix(log.suffix+'.exit').write_text(str(p.returncode)+'\n')
    if p.returncode:raise RuntimeError('Failed '+str(log))
def descriptor(d):
    fmts={'f32':0,'bf16':1,'u8':2,'i4row':3,'i4head':4,'i4group32':5};shape=d['shape']+[1]*(3-len(d['shape']))
    word=(1<<255)|(fmts[d['format']]<<252)|(len(d['shape'])<<250)
    fields=shape+[d['data_bytes'],d['scale_offset'],0 if d['scale_shape']is None else __import__('math').prod(d['scale_shape']),d['capacity_bytes']]
    for i,v in enumerate(fields):word|=v<<(192-i*32)
    return word

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,required=True);ap.add_argument('--mode',choices=['sim','lint','synth','all'],default='all');ap.add_argument('--profiles',nargs='+',default=PROFILES);a=ap.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    packet=BASE/'modules/attention_tensor_executor.json';assert sha(packet)=='0023e5d80df0b358aadc30431dc9ca38279cf6e51d8d9fc534333453ee7c0292';doc=json.loads(packet.read_text())
    pins=dict(doc['common_contracts'])
    for key in ['rtl_contract','isa','child_quantizer','child_quantizer_contract','math_contract']:pins[doc[key]['path']]=doc[key]['sha256']
    for name,h in pins.items():assert sha(ROOT/name)==h,name
    tb=BASE/'tb/tb_attention_executor.sv';files=[*SOURCES,tb,Path(__file__),BASE/'scripts/executor_ooc.tcl',packet,*[ROOT/n for n in pins],BASE/'scripts/make_rtl_vectors.py',BASE/'python/attention_hardware_reference.py',BASE/'isa_program.py',BASE/'reference/fp32_reference.py',BASE/'reference/exp_reference.py',ROOT/'designs/attention_int4_noscale_zcu104_r1/scripts/xsim_runtime.py']
    if a.mode in ['sim','all']:
      for profile in a.profiles:
        v=BASE/'rtl_vectors'/profile;w=out/profile;w.mkdir();cfg=json.loads((v/'descriptor_table.json').read_text())
        for p in v.iterdir():
          if p.suffix in ['.mem','.json']:shutil.copyfile(p,w/p.name);files.append(p)
        (w/'descriptor.mem').write_text('\n'.join(f'{descriptor(d):064x}'for d in cfg['banks'])+'\n')
        factor=struct.unpack('<I',struct.pack('<f',1/(cfg['head_dim']**.5)))[0]
        context=[cfg['banks'][0]['shape'][0],cfg['heads'],cfg['head_dim'],len(cfg['query_indices']),int(cfg['causal']),factor]
        (w/'context.mem').write_text('\n'.join(f'{x:08x}'for x in context)+'\n');(w/'query.mem').write_text('\n'.join(f'{x:08x}'for x in cfg['query_indices']+[0]*(32-len(cfg['query_indices'])))+'\n')
        files.extend(w/n for n in ['descriptor.mem','context.mem','query.mem'])
    manifest={'packet_sha256':sha(packet),'top':'attention_tensor_executor','part':'xczu7ev-ffvc1156-2-e','clock_ns':5,'mode':a.mode,'sources':{str(p):sha(p)for p in dict.fromkeys(files)}}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for name,h in manifest['sources'].items():
      p=Path(name);rel=p.relative_to(ROOT)if p.is_relative_to(ROOT)else Path('generated')/p.name;target=out/'source_snapshot'/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target);assert sha(target)==h
    run(['verilator','--version'],out,out/'version.log')
    run(['verilator','--lint-only','-Wall','--top-module','attention_tensor_executor',*SOURCES],out,out/'lint.log')
    if a.mode in ['sim','all']:
      for profile in a.profiles:
        work=out/profile;run([VIVADO/'xvlog','--sv',*SOURCES,tb],work,work/'compile.log')
        run([VIVADO/'xelab','tb_attention_executor','-s','executor_sim','-timescale','1ns/1ps'],work,work/'elaborate.log')
        snapshot_run(work/'xsim.dir/executor_sim/xsimk',work,work/'simulation.log','ATTENTION_EXECUTOR_XSIM_PASS')
    if a.mode in ['synth','all']:
      v=Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin/vivado');work=out/'ooc';work.mkdir();(work/'sources.tcl').write_text('\n'.join('read_verilog -sv {'+str(p)+'}'for p in SOURCES)+'\n')
      run([v,'-version'],work,work/'version.log');run([v,'-mode','batch','-source',BASE/'scripts/executor_ooc.tcl','-tclargs',work],work,work/'synthesis.log')
      assert (work/'synthesis.log').read_text().splitlines().count('ATTENTION_EXECUTOR_OOC_PASS')==1
    for name,h in manifest['sources'].items():assert sha(Path(name))==h,name
    (out/'result.json').write_text(json.dumps({'result':'PASS','source_identity':'PASS','mode':a.mode,'profiles':a.profiles,'child_validation':'separate arithmetic acceptance required','limitations':['scalar bounded tensor executor, local-memory BFM only','unplaced synthesis estimate not board/routed','no pretrained model accuracy claim']},indent=2)+'\n')
    print('ATTENTION_EXECUTOR_CHECK_PASS');print(out)
if __name__=='__main__':main()
