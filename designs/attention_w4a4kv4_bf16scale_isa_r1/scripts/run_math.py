import argparse,pathlib,sys,json,hashlib,subprocess,shutil,re
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
        try:result=subprocess.run([str(x) for x in cmd],cwd=cwd,stdout=f,stderr=subprocess.STDOUT,timeout=timeout)
        except subprocess.TimeoutExpired:
            path.with_suffix(path.suffix+'.exit').write_text('TIMEOUT\n');raise
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
    closure=sources+pins+[BASE/'tb/tb_attention_math.sv']+sorted((BASE/'reference').glob('fp32_*py'))+sorted((BASE/'reference').glob('exp_*py'))+sorted((BASE/'scripts').glob('math_*'))+[BASE/'scripts/run_math.py',ROOT/'designs/attention_int4_noscale_zcu104_r1/scripts/xsim_runtime.py']
    hashes={str(p):sha(p) for p in closure};(out/'source_snapshot').mkdir()
    for p in closure:
        q=out/'source_snapshot'/p.relative_to(ROOT);q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
    vectors=generate(out)
    manifest={'sources':hashes,'packet_sha256':sha(packet),'part':contract['hardware']['part'],'clock_ns':5.0,'mode':args.mode,'vectors':vectors}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    logged(['verilator','--version'],ROOT,out/'verilator_version.log')
    logged([VIVADO,'-version'],ROOT,out/'vivado_version.log')
    for top in ['attention_fp32_alu','attention_exp_neg']:
        logged(['verilator','--lint-only','--sv','-Wall','--top-module',top,*([sources[0]] if top=='attention_fp32_alu' else sources)],ROOT,out/f'lint_{top}.log')
    if args.mode in ('sim','all'):
        work=out/'xsim';work.mkdir()
        for name in ['alu.hex','exp.hex']:shutil.copyfile(out/name,work/name)
        logged([VIVADO.parent/'xvlog','--sv',*sources,BASE/'tb/tb_attention_math.sv'],work,work/'compile.log')
        logged([VIVADO.parent/'xelab','tb_attention_math','-s','math_sim','-generic_top',f'ALU_COUNT={vectors["alu_cases"]}','-generic_top',f'EXP_COUNT={vectors["exp_cases"]}','-timescale','1ns/1ps'],work,work/'elaborate.log')
        sys.path.insert(0,str(ROOT/'designs/attention_int4_noscale_zcu104_r1/scripts'))
        from xsim_runtime import snapshot_run
        snapshot_run(work/'xsim.dir/math_sim/xsimk',work,work/'simulation.log','ATTENTION_MATH_SIM_PASS')
    metrics={}
    if args.mode in ('synth','all'):
        for top in ['attention_fp32_alu','attention_exp_neg']:
            work=out/top;work.mkdir()
            logged([VIVADO,'-mode','batch','-source',BASE/'scripts/math_ooc.tcl','-tclargs',top,work,BASE/'rtl'],work,work/'synthesis.log','ATTENTION_MATH_OOC_PASS')
            text=(work/'timing_summary.rpt').read_text()
            table=text.split('WNS(ns)',1)[1].splitlines()[2].split()
            timing={'wns_ns':float(table[0]),'setup_failing':int(table[2]),'whs_ns':float(table[4]),'hold_failing':int(table[6]),'wpws_ns':float(table[8]),'pulse_failing':int(table[10])}
            util=(work/'utilization.rpt').read_text()
            def used(label):
                match=re.search(r'\| '+re.escape(label)+r'\s*\|\s*(\d+)',util)
                return int(match.group(1)) if match else None
            metrics[top]={'timing':timing,'resources':{'lut':used('CLB LUTs*'),'ff':used('CLB Registers'),'dsp':used('DSPs'),'bram_tiles':used('Block RAM Tile'),'uram':used('URAM')},'drc_report':str(work/'drc.rpt'),'methodology_report':str(work/'methodology.rpt')}
            assert all(timing[k]>=0 for k in ['wns_ns','whs_ns','wpws_ns']) and not any(timing[k] for k in ['setup_failing','hold_failing','pulse_failing']),timing
    assert all(sha(pathlib.Path(p))==h for p,h in hashes.items())
    (out/'result.json').write_text(json.dumps({'result':'PASS','source_identity':'PASS','mode':args.mode,'vectors':vectors,'limitations':'OOC unplaced synthesis estimate; external hold excluded, no routed or board claim'},indent=2)+'\n')
    report={'module_id':'attention_fp32_math','status':'PASS','source_identity':'PASS','manifest_sha256':sha(out/'manifest.json'),'simulation_cases':vectors,'metrics':metrics,'protocol':'one outstanding; variable latency; response retained until accepted; reset cancels','arithmetic':'exact finite FP32 RNE including gradual underflow; nonfinite/div0/overflow error','scope':'Arithmetic primitives only; no full Attention/ISA/board/routed timing claim','timing_scope':'5ns unplaced OOC synthesis estimate; I/O max0.5ns,min0; external hold paths excluded','resource_assessment':'underutilized'}
    (out/'kernel_report.json').write_text(json.dumps(report,indent=2)+'\n')
    (out/'module_ooc_synthesis_report.json').write_text(json.dumps(metrics,indent=2)+'\n')
    (out/'subagent_result.json').write_text(json.dumps({'status':'PASS','changed_files':[str(p) for p in closure if p.is_relative_to(BASE)],'evidence':str(out),'remaining_risks':['Unplaced estimates; external I/O hold excluded','Exp numerical bounds apply only declared negative domain; zero cutoff below -80'],'skill_update_candidate':'contracts/README minimal packet workflow supersedes removed design_contracts.py gate in installed skills'},indent=2)+'\n')
    print(out)
if __name__=='__main__':main()
