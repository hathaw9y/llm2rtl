"""Source-bound real Attention tensor ISA fixture; child promotion gates mandatory."""
import argparse,hashlib,json,pathlib,re,shutil,subprocess,sys
BASE=pathlib.Path(__file__).resolve().parents[1];ROOT=BASE.parents[1]
sys.path.insert(0,str(ROOT/'designs/attention_int4_noscale_zcu104_r1/scripts'))
from xsim_runtime import snapshot_run,VIVADO
PROFILES=['prefill','last_token','odd_head','noncausal_mask','all_masked','zero','gentle','max_tokens','max_row']
QUANT=ROOT/'designs/attention_int4_noscale_zcu104_r1/rtl/attention_int4_quantizer.sv'
SHARED=[ROOT/'ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv',ROOT/'ip/infrastructure/bank_port_router/rtl/bank_port_router.sv',ROOT/'ip/infrastructure/datamover_engine/rtl/bram_bank.sv']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(cmd,cwd,log):
    if log.exists():raise RuntimeError('Existing log '+str(log))
    with log.open('w')as f:
        try:p=subprocess.run(list(map(str,cmd)),cwd=cwd,stdout=f,stderr=subprocess.STDOUT,timeout=1200)
        except subprocess.TimeoutExpired:log.with_suffix(log.suffix+'.exit').write_text('TIMEOUT\n');raise
    log.with_suffix(log.suffix+'.exit').write_text(str(p.returncode)+'\n')
    if p.returncode:raise RuntimeError('Failed '+str(log))
def check_reviews(paths):
    for module,path in paths:
        if path is None:raise RuntimeError('Independent child review required: '+module)
        report=json.loads(path.read_text())
        if report.get('status',report.get('result')) not in ['passed','PASS'] or report.get('module_id',module)!=module:raise RuntimeError('Unaccepted child '+str(path))
        sources=report.get('sources',report.get('source_hashes',report.get('identity')))
        if not isinstance(sources,dict):raise RuntimeError('Child review missing source hashes '+str(path))
        for f,h in sources.items():
            p=pathlib.Path(f);p=p if p.is_absolute() else ROOT/p;assert sha(p)==h,f

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=pathlib.Path);ap.add_argument('--profiles',nargs='+',choices=PROFILES,default=PROFILES);ap.add_argument('--mode',choices=['prepare','sim','lint','synth','all'],default='all');ap.add_argument('--math-review',type=pathlib.Path);ap.add_argument('--executor-review',type=pathlib.Path);ap.add_argument('--cmd-read-latency',type=int,choices=[1,2],default=1);args=ap.parse_args()
    packet=BASE/'modules/attention_tensor_isa_validation.json';assert sha(packet)=='74a112af3ddb22996ddfa16759f373b54c61c7f2ab9af326fd52ee2e2b277531'
    contract=json.loads(packet.read_text());pins=[packet]
    for f,h in contract['common_contracts'].items():p=ROOT/f;assert sha(p)==h,f;pins.append(p)
    for key in ['rtl_contract','control_contract','executor_contract','math_contract','math_manifest','vector_generator','numeric_golden']:
        item=contract[key];p=ROOT/item['path'];assert sha(p)==item['sha256'],key;pins.append(p)
    if args.mode!='prepare':check_reviews([('attention_fp32_math',args.math_review),('attention_tensor_executor',args.executor_review)])
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
    common=[BASE/'rtl'/f for f in ['attention_tensor_pkg.sv','attention_fp32_alu.sv','attention_fp32_exp_rom.sv','attention_exp_neg.sv']]+[QUANT]+[BASE/'rtl'/f for f in ['attention_tensor_executor.sv','attention_descriptor_rom.sv','attention_tensor_controller.sv','attention_tensor_bank_subsystem.sv','attention_tensor_isa_top.sv']]+SHARED
    files=common+pins+[BASE/'tb/tb_attention_tensor_isa.sv',BASE/'scripts/run_tensor_isa.py',BASE/'scripts/tensor_isa_ooc.tcl',BASE/'scripts/generate_tensor_config.py',BASE/'scripts/control_lint.vlt',BASE/'isa_program.py',ROOT/'designs/attention_int4_noscale_zcu104_r1/scripts/xsim_runtime.py']
    if args.math_review:files.append(args.math_review.resolve())
    if args.executor_review:files.append(args.executor_review.resolve())
    configs={}
    for profile in args.profiles:
        vectors=BASE/'rtl_vectors'/profile;report=json.loads((vectors/'golden_report.json').read_text());files.append(vectors/'golden_report.json')
        for name,h in report['artifact_hashes'].items():p=vectors/name;assert sha(p)==h,p;files.append(p)
        for name,h in report['source_hashes'].items():p=pathlib.Path(name);assert sha(p)==h,p;files.append(p)
        work=out/profile;work.mkdir()
        for p in vectors.glob('*.mem'):shutil.copyfile(p,work/p.name)
        run(['python3',BASE/'scripts/generate_tensor_config.py','--descriptor',vectors/'descriptor_table.json','--output-dir',work/'generated'],ROOT,work/'generation.log')
        configs[profile]=work/'generated/attention_tensor_config_pkg.sv';files.append(configs[profile])
    stub=out/'lint/bram_bank.sv';stub.parent.mkdir()
    stub.write_text('/* verilator lint_off UNUSED */\n/* verilator lint_off UNDRIVEN */\n'+SHARED[-1].read_text().split(');',1)[0]+');\nendmodule\n/* verilator lint_on UNDRIVEN */\n/* verilator lint_on UNUSED */\n')
    files.append(stub)
    hashes={str(p):sha(p)for p in files}
    manifest={'sources':hashes,'profiles':args.profiles,'packet_sha256':sha(packet),'part':'xczu7ev-ffvc1156-2-e','clock_ns':5.0,'mode':args.mode,'children':{'math_review':str(args.math_review),'executor_review':str(args.executor_review)},'configuration':{'CMD_ADDR_WIDTH':6,'MAX_COMMANDS':64,'CMD_READ_LATENCY':args.cmd_read_latency},'real_executor':True,'DMA_peers':'native BFMs, no vendor DataMover/physical DDR'}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for f,h in hashes.items():
        p=pathlib.Path(f);rel=p.relative_to(ROOT) if p.is_relative_to(ROOT) else pathlib.Path('generated')/p.relative_to(out) if p.is_relative_to(out) else pathlib.Path('external')/h/p.name
        q=out/'source_snapshot'/rel;q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q);assert sha(q)==h
    run(['verilator','--version'],out,out/'verilator_version.log');run([VIVADO/'vivado','-version'],out,out/'vivado_version.log')
    for profile in args.profiles:
        work=out/profile;sources=[common[0],configs[profile]]+common[1:]
        if args.mode in ['lint','all']:
            lint_sources=[p for p in sources if p!=SHARED[-1]]+[stub]
            run(['verilator','--lint-only','--sv','-Wall','--top-module','attention_tensor_isa_top',BASE/'scripts/control_lint.vlt',*lint_sources],work,work/'lint.log')
        if args.mode in ['prepare','sim','all']:
            run([VIVADO/'xvlog','--sv',*sources,BASE/'tb/tb_attention_tensor_isa.sv'],work,work/'compile.log')
            run([VIVADO/'xelab','tb_attention_tensor_isa','-L','xpm','-s','tensor_isa_sim','-timescale','1ns/1ps','-generic_top',f'NEGATIVE_TESTS={int(profile=="prefill")}','-generic_top',f'CMD_READ_LATENCY={args.cmd_read_latency}'],work,work/'elaborate.log')
            if args.mode!='prepare':snapshot_run(work/'xsim.dir/tensor_isa_sim/xsimk',work,work/'simulation.log','ATTENTION_TENSOR_ISA_XSIM_PASS')
    metrics={}
    if args.mode in ['synth','all']:
        profile=args.profiles[0];sources=[common[0],configs[profile]]+common[1:];work=out/'ooc';work.mkdir()
        (work/'sources.tcl').write_text('\n'.join('read_verilog -sv {'+str(p)+'}'for p in sources)+'\n')
        run([VIVADO/'vivado','-mode','batch','-source',BASE/'scripts/tensor_isa_ooc.tcl','-tclargs',work,args.cmd_read_latency],work,work/'synthesis.log')
        assert (work/'synthesis.log').read_text().splitlines().count('ATTENTION_TENSOR_ISA_OOC_PASS')==1
        table=(work/'timing_summary.rpt').read_text().split('WNS(ns)',1)[1].splitlines()[2].split()
        timing={'wns_ns':float(table[0]),'setup_failing':int(table[2]),'whs_ns':float(table[4]),'hold_failing':int(table[6]),'wpws_ns':float(table[8]),'pulse_failing':int(table[10])}
        assert all(timing[k]>=0 for k in ['wns_ns','whs_ns','wpws_ns'])and not any(timing[k]for k in ['setup_failing','hold_failing','pulse_failing'])
        row=re.search(r'\| attention_tensor_isa_top\s*\|[^\n]+',(work/'utilization.rpt').read_text()).group(0);r=[v.strip()for v in row.split('|')][3:-1]
        metrics={'profile':profile,'timing':timing,'resources':dict(zip(['total_lut','logic_lut','lutram','srl','ff','ramb36','ramb18','uram','dsp'],map(int,r))), 'scope':'unplaced OOC with external boundary hold excluded'}
    for f,h in hashes.items():assert sha(pathlib.Path(f))==h,f
    result={'status':'PREPARED_NO_DYNAMIC_PASS'if args.mode=='prepare'else'PASS'if args.mode in ['sim','all']else args.mode.upper()+'_PASS_ONLY','source_identity':'PASS','mode':args.mode,'profiles':args.profiles,'metrics':metrics,'limitations':['bounded immutable descriptors; native DMA BFMs, no physical DDR/board/routed/model quality claim','compute memory stalls independently covered by executor BFM, not fake forced ready in full top']}
    (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    if args.mode in ['sim','all']:
        verification={'module_id':'attention_tensor_isa','status':'passed','role':'integration_test_author_real_source_readonly','sources':hashes,'manifest_sha256':sha(out/'manifest.json'),'child_math_review':str(args.math_review),'child_executor_review':str(args.executor_review),'profiles':args.profiles,'configuration':manifest['configuration'],'claims':['actual command BRAM/controller/native XPM/real compute/S2MM path','canonical21 and diagnostic34 continuous repeated start; exact all13computed tensorexports','saved completion identities, read consumption, accepted finalwrite/release/END ordering','five real compute completion/RELEASE late bank faults: immediate rejected acceptance, retained ownership, invalid destination, no physical touch; isolated router fault signal injection only'],'lint_scope':'strict -Wall; only explicit legacy ascending-packed LITENDIAN filename rules and vendor memory interface stub-local unused/undriven annotations','limitations':result['limitations'],'source_identity':'PASS','metrics':metrics}
        (out/'integration_verification_report.json').write_text(json.dumps(verification,indent=2)+'\n')
    if args.mode in ['synth','all']:
        (out/'integration_synthesis_report.json').write_text(json.dumps({'top':'attention_tensor_isa_top','configuration':manifest['configuration'],'source_identity':'PASS','manifest_sha256':sha(out/'manifest.json'),'metrics':metrics,'scope':'unplaced OOC5ns; external I/O hold exclusions, no board/routed claim'},indent=2)+'\n')
    print(out)
if __name__=='__main__':main()
