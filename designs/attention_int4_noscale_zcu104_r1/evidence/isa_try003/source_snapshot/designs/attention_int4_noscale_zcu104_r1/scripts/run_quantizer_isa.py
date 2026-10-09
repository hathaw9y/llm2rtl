#!/usr/bin/env python3
"""Source-bound ISA controller/executor/native XPM integration verification."""
import argparse,hashlib,json,shutil,subprocess,sys
from pathlib import Path
from xsim_runtime import snapshot_run,VIVADO
from isa_test_vectors import write_isa_vectors
BASE=Path(__file__).resolve().parents[1];ROOT=BASE.parents[1]

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def logged(command,work,log):
    if log.exists():raise RuntimeError(f'Cannot replace evidence {log}')
    with log.open('w') as stream:
        p=subprocess.run([str(x) for x in command],cwd=work,stdout=stream,stderr=subprocess.STDOUT,timeout=600)
    log.with_suffix(log.suffix+'.exit').write_text(str(p.returncode)+'\n')
    if p.returncode:raise RuntimeError(f'Exit{p.returncode}; see {log}')
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=Path);ap.add_argument('--mode',choices=['sim','lint','synth','all'],default='all');a=ap.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    packet=BASE/'modules/attention_quantizer_isa.json';pin='cb0734d094aaa449f4f1cdcee01ac0f3cc43aac427bc1aab0288d7850d027a47'
    if sha(packet)!=pin:raise RuntimeError('ISA packet hash mismatch')
    addendum=BASE/'modules/attention_quantizer_isa_generation_addendum.json'
    if sha(addendum)!='ab828c7a28def8494661c4f17378a20d265028160dd0626989a22132cc1b6de1':raise RuntimeError('Generation addendum changed')
    doc=json.loads(packet.read_text());pins=dict(doc['common_contracts'])
    for name in ['child','child_contract','child_independent_review','native_contract','controller_contract','controller_index']:
        ref=doc[name];pins[ref['path']]=ref['sha256']
    for name,digest in pins.items():
        if sha(ROOT/name)!=digest:raise RuntimeError('Pinned input changed: '+name)
    native=ROOT/'ip/infrastructure';rtl=BASE/'rtl'
    sources=[rtl/'attention_quantizer_bank_config_pkg.sv',native/'bank_subsystem/rtl/bank_native_ownership.sv',native/'bank_subsystem/rtl/bank_native_router.sv',native/'bank_subsystem/rtl/bank_native_memories.sv',native/'datamover_engine/rtl/bram_bank.sv',native/'datamover_engine/rtl/uram_bank.sv',rtl/'attention_int4_quantizer.sv',rtl/'attention_quantizer_controller.sv',rtl/'attention_quantizer_executor.sv',rtl/'attention_quantizer_bank_subsystem.sv',rtl/'attention_quantizer_isa_top.sv']
    tb=BASE/'tb/tb_attention_quantizer_isa.sv'
    files=[*sources,tb,packet,addendum,*[ROOT/name for name in pins],BASE/'reference/quantizer_reference.py',BASE/'reference/isa_encoder.py',*[BASE/'scripts'/name for name in ['run_quantizer_isa.py','isa_test_vectors.py','quantizer_isa_ooc.tcl','xsim_runtime.py','generate_quantizer_isa.py','check_quantizer_isa.py']],native/'cmd_dispatcher_template/rtl/cmd_dispatcher_template.sv',native/'bank_subsystem_template/rtl/bank_subsystem.sv.tpl',native/'bank_subsystem_template/rtl/bank_config_pkg.sv.tpl']
    if a.mode in ['sim','all']:
        work=out/'xsim';work.mkdir();rows,bad=write_isa_vectors(work)
        files.extend(work/name for name in ['isa_inputs.hex','isa_outputs.hex','isa_metadata.hex','isa_programs.hex','isa_bad_programs.hex','isa_reference_rows.json'])
    identity={'packet_sha256':pin,'part':'xczu7ev-ffvc1156-2-e','clock_ns':5.0,'top':'attention_quantizer_isa_top','mode':a.mode,'sources':{str(p):sha(p) for p in dict.fromkeys(files)}}
    logged([VIVADO/'vivado','-version'],out,out/'version.log');identity['tool_version']=(out/'version.log').read_text()
    (out/'manifest.json').write_text(json.dumps(identity,indent=2)+'\n')
    for name,digest in identity['sources'].items():
        source=Path(name);relative=source.relative_to(ROOT) if source.is_relative_to(ROOT) else Path('generated')/source.name
        target=out/'source_snapshot'/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
        if sha(target)!=digest:raise RuntimeError('Snapshot changed')
    logged(['python3',BASE/'scripts/check_quantizer_isa.py','--require-rtl'],ROOT,out/'contract_gate.log')
    if a.mode in ['sim','all']:
        logged([VIVADO/'xvlog','--sv',*sources,tb],work,work/'compile.log')
        name='attention_quantizer_isa_sim'
        logged([VIVADO/'xelab','tb_attention_quantizer_isa','-L','xpm','-generic_top',f'ROW_COUNT={rows}','-generic_top',f'BAD_COUNT={bad}','-s',name,'-timescale','1ns/1ps'],work,work/'elaborate.log')
        snapshot_run(work/'xsim.dir'/name/'xsimk',work,work/'simulation.log','ATTENTION_QUANTIZER_ISA_XSIM_PASS')
    if a.mode in ['lint','all']:
        logged(['verilator','--version'],out,out/'verilator_version.log')
        logged(['verilator','--lint-only','--sv','-Wall','-Wno-UNUSED','--top-module','attention_quantizer_isa_top',*sources],out,out/'lint.log')
    if a.mode in ['synth','all']:
        work=out/'ooc';work.mkdir();(work/'sources.tcl').write_text('\n'.join('read_verilog -sv {'+str(p)+'}' for p in sources)+'\n')
        logged([VIVADO/'vivado','-mode','batch','-source',BASE/'scripts/quantizer_isa_ooc.tcl','-tclargs',work],work,work/'synthesis.log')
        if (work/'synthesis.log').read_text().splitlines().count('ATTENTION_QUANTIZER_ISA_OOC_PASS')!=1:raise RuntimeError('Exact OOC PASS absent')
    for name,digest in identity['sources'].items():
        if sha(Path(name))!=digest:raise RuntimeError('Source changed during run: '+name)
    (out/'result.json').write_text(json.dumps({'result':'PASS','mode':a.mode,'source_identity':'PASS','rows':rows if a.mode in ['sim','all'] else None,'limitations':['DMA peers are BFMs, no vendorDataMover instance','no full Attention datapath or quality/board claim','OOC timing is unplaced estimate with external hold exclusions']},indent=2)+'\n')
    print('ATTENTION_QUANTIZER_ISA_CHECK_PASS');print(out)
if __name__=='__main__':main()
