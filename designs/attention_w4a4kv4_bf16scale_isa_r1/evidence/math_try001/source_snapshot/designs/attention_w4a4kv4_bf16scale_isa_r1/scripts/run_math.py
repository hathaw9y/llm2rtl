import argparse,pathlib,sys,json,hashlib,subprocess,shutil
BASE=pathlib.Path(__file__).resolve().parents[1];ROOT=BASE.parents[1]
sys.path.insert(0,str(BASE/'scripts'));from math_vectors import generate
VIVADO=pathlib.Path('/opt/Xilinx/2025.2/Vivado/bin/vivado')
if not VIVADO.exists():
    VIVADO=pathlib.Path('/tools/Xilinx/2025.2/Vivado/bin/vivado')
if not VIVADO.exists():
    old=ROOT/'designs/attention_int4_noscale_zcu104_r1/scripts'
    sys.path.insert(0,str(old));from xsim_runtime import VIVADO as VB
    VIVADO=VB/'vivado'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def logged(cmd,cwd,path,marker=None,timeout=900):
    with path.open('w') as f:
        result=subprocess.run([str(x) for x in cmd],cwd=cwd,stdout=f,stderr=subprocess.STDOUT,timeout=timeout)
    path.with_suffix(path.suffix+'.exit').write_text(str(result.returncode)+'\n')
    if result.returncode:raise RuntimeError(f'{path} exit{result.returncode}')
    if marker and marker not in path.read_text().splitlines():raise RuntimeError(f'missing exact marker {path}')
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--mode',choices=['sim','synth','all'],default='all');args=ap.parse_args()
    out=pathlib.Path(args.out).resolve();out.mkdir(parents=True,exist_ok=False)
    packet=BASE/'modules/attention_fp32_math.json';assert sha(packet)=='5b24dfa7f8dd8db519cf807b40df0b5e830c22be8379d23e30b072007a934421'
    contract=json.loads(packet.read_text());pins=[packet]
    for f,h in contract['common_contracts'].items():
        p=ROOT/f;assert sha(p)==h;pins.append(p)
    sources=sorted((BASE/'rtl').glob('attention_fp32_*.sv'))+[BASE/'rtl/attention_exp_neg.sv']
    closure=sources+pins+[BASE/'tb/tb_attention_math.sv']+sorted((BASE/'reference').glob('fp32_*py'))+sorted((BASE/'reference').glob('exp_*py'))+sorted((BASE/'scripts').glob('math_*'))+[BASE/'scripts/run_math.py']
    hashes={str(p):sha(p) for p in closure};(out/'source_snapshot').mkdir()
    for p in closure:
        q=out/'source_snapshot'/p.relative_to(ROOT);q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
    vectors=generate(out)
    manifest={'sources':hashes,'packet_sha256':sha(packet),'part':contract['hardware']['part'],'clock_ns':5.0,'mode':args.mode,'vectors':vectors}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    logged(['verilator','--version'],ROOT,out/'verilator_version.log')
    logged([VIVADO,'-version'],ROOT,out/'vivado_version.log')
    for top in ['attention_fp32_alu','attention_exp_neg']:
        logged(['verilator','--lint-only','--sv','-Wall','--top-module',top,*sources],ROOT,out/f'lint_{top}.log')
    if args.mode in ('sim','all'):
        build=out/'build'
        logged(['verilator','--binary','--timing','-Wno-fatal','--top-module','tb_attention_math','--Mdir',build,'-j','4',*sources,BASE/'tb/tb_attention_math.sv'],ROOT,out/'compile.log')
        logged([build/'Vtb_attention_math',f'+VECTORS={out}',f'+ALU_COUNT={vectors["alu_cases"]}',f'+EXP_COUNT={vectors["exp_cases"]}'],ROOT,out/'simulation.log','ATTENTION_MATH_SIM_PASS',600)
    if args.mode in ('synth','all'):
        for top in ['attention_fp32_alu','attention_exp_neg']:
            work=out/top;work.mkdir()
            logged([VIVADO,'-mode','batch','-source',BASE/'scripts/math_ooc.tcl','-tclargs',top,work,BASE/'rtl'],work,work/'synthesis.log','ATTENTION_MATH_OOC_PASS')
    assert all(sha(pathlib.Path(p))==h for p,h in hashes.items())
    (out/'result.json').write_text(json.dumps({'result':'PASS','source_identity':'PASS','mode':args.mode,'vectors':vectors,'limitations':'OOC unplaced synthesis estimate; external hold excluded, no routed or board claim'},indent=2)+'\n')
    print(out)
if __name__=='__main__':main()
