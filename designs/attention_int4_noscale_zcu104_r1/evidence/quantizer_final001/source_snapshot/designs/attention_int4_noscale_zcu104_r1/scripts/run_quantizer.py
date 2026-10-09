#!/usr/bin/env python3
"""Independent quantizer source-bound XSIM, strict lint, and OOC checks."""
import argparse,hashlib,json,shutil,subprocess,sys
from pathlib import Path
from xsim_runtime import snapshot_run,VIVADO
BASE=Path(__file__).resolve().parents[1];ROOT=BASE.parents[1]
sys.path.insert(0,str(BASE/'reference'))
from quantizer_reference import write_vectors

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
    rtl=BASE/'rtl/attention_int4_quantizer.sv';tb=BASE/'tb/tb_attention_int4_quantizer.sv'
    packet=BASE/'modules/attention_int4_quantizer.json';expected='25f32c88bfda1ae3285b4c892b52301ebf490d9da46c618b95b7d44960906361'
    if sha(packet)!=expected:raise RuntimeError('Quantizer packet hash changed')
    sources=[rtl,tb,packet,*sorted((BASE/'scripts').glob('*.*')),*sorted((BASE/'reference').glob('*.py')),ROOT/'contracts/common/engine_completion_contract.json',ROOT/'contracts/common/evidence_identity_contract.json']
    profiles={}
    if a.mode in ['sim','all']:
        for maximum in [13,256]:
            work=out/f'xsim_max{maximum}';work.mkdir();rows=write_vectors(work,maximum)
            profiles[maximum]=(work,rows)
            sources.extend(work/name for name in ['inputs.hex','outputs.hex','metadata.hex','reference_rows.json'])
    identity={'packet_sha256':expected,'part':'xczu7ev-ffvc1156-2-e','clock_ns':5.0,'top':'attention_int4_quantizer','mode':a.mode,'sources':{str(p):sha(p) for p in sources}}
    logged([VIVADO/'vivado','-version'],out,out/'version.log');identity['tool_version']=(out/'version.log').read_text()
    (out/'manifest.json').write_text(json.dumps(identity,indent=2)+'\n')
    for name,digest in identity['sources'].items():
        source=Path(name)
        relative=source.relative_to(ROOT) if source.is_relative_to(ROOT) else Path('generated')/source.name
        target=out/'source_snapshot'/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
        if sha(target)!=digest:raise RuntimeError('Snapshot changed')
    if a.mode in ['sim','all']:
        for maximum,(work,rows) in profiles.items():
            logged([VIVADO/'xvlog','--sv',rtl,tb],work,work/'compile.log')
            name=f'quantizer_max{maximum}'
            logged([VIVADO/'xelab','tb_attention_int4_quantizer','-generic_top',f'MAX_ELEMENTS={maximum}','-generic_top',f'ROW_COUNT={rows}','-s',name,'-timescale','1ns/1ps'],work,work/'elaborate.log')
            snapshot_run(work/'xsim.dir'/name/'xsimk',work,work/'simulation.log','ATTENTION_INT4_QUANTIZER_XSIM_PASS')
    if a.mode in ['lint','all']:
        logged(['verilator','--version'],out,out/'verilator_version.log')
        logged(['verilator','--lint-only','--sv','-Wall','--top-module','attention_int4_quantizer',rtl],out,out/'lint.log')
    if a.mode in ['synth','all']:
        work=out/'ooc';work.mkdir()
        logged([VIVADO/'vivado','-mode','batch','-source',BASE/'scripts/quantizer_ooc.tcl','-tclargs',rtl,work],work,work/'synthesis.log')
        if (work/'synthesis.log').read_text().splitlines().count('ATTENTION_INT4_QUANTIZER_OOC_PASS')!=1:raise RuntimeError('Exact OOC PASS absent')
    for name,digest in identity['sources'].items():
        if sha(Path(name))!=digest:raise RuntimeError('Source changed during run: '+name)
    (out/'result.json').write_text(json.dumps({'result':'PASS','mode':a.mode,'source_identity':'PASS','profiles':{str(k):v[1] for k,v in profiles.items()},'limitations':['no full Attention accuracy or integration claim','no route/board signoff']},indent=2)+'\n')
    print('ATTENTION_INT4_QUANTIZER_CHECK_PASS');print(out)
if __name__=='__main__':main()
