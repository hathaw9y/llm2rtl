#!/usr/bin/env python3
"""Independent T03 evaluator. Candidate PASS files/fixtures are never loaded."""
from __future__ import annotations
import argparse, ast, dataclasses, hashlib, json, pathlib, subprocess, sys, time
BASE = pathlib.Path(__file__).resolve().parents[1]
FIX = BASE/'evaluator/t03'
DESIGN = pathlib.Path('designs/smollm2_135m_bf16_zcu104_r1')
PHASE='all'
def selected_counts():
    public=(1,2,8,16,31,32)
    return public if PHASE=='public' else tuple(c for c in range(1,33) if c not in public) if PHASE=='hidden' else range(1,33)

PROTO = pathlib.Path('verification/prototypes/smollm2_135m_isa_feasibility.py')

def run(cmd, cwd, logfile, timeout=300):
    p=subprocess.run(list(map(str,cmd)),cwd=cwd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
    logfile.write_text(p.stdout)
    if p.returncode: raise AssertionError(f'command failed ({p.returncode}): {cmd}; see {logfile}')
    return p.stdout

def namespace(path):
    # Read actual candidate definitions, omit imports/main/model construction.
    tree=ast.parse(path.read_text())
    selected=[ast.ImportFrom(module='__future__',names=[ast.alias(name='annotations')],level=0)]
    selected += [n for n in tree.body if isinstance(n,(ast.FunctionDef,ast.ClassDef,ast.Assign,ast.AnnAssign))]
    ns={'dataclass':dataclasses.dataclass,'field':dataclasses.field,'Path':pathlib.Path,'Counter':__import__('collections').Counter,
        'hashlib':hashlib,'json':json}
    exec(compile(ast.fix_missing_locations(ast.Module(body=selected,type_ignores=[])),str(path),'exec'),ns)
    return ns

def expected_dense(count,start=0,n=0,total=192,k=16,tile=192,baseline=False):
    return (3<<124)|(2<<120)|(3<<116)|(4<<112)|(n<<47)|(total<<31)|(start<<25)|((count if baseline else count-1)<<19)|(k<<8)|tile

def rejected(fn):
    try: fn()
    except (AssertionError,ValueError,IndexError,RuntimeError): return
    raise AssertionError('invalid command accepted')

def python_gate(root,baseline):
    ns=namespace(root/PROTO); Cmd=ns['Cmd']; enc=ns['wire_record']; dec=ns['wire_decode']
    count_tests=0
    for count in selected_counts():
        for start in (0,32-count):
            cmd=Cmd('GEMM',(2,3,4,0,192,start,count,16,192))
            record=enc(cmd,None)
            assert record==expected_dense(count,start,baseline=baseline),(count,start,hex(record))
            assert dec(record,None)==cmd
            count_tests+=1
    if not baseline:
        for raw in range(32,64):
            wire=expected_dense(1,baseline=True)&~(63<<19)|raw<<19
            rejected(lambda:dec(wire,None))
        for count in selected_counts():
            bad=expected_dense(count,33-count)
            rejected(lambda:dec(bad,None))
            rejected(lambda:enc(Cmd('GEMM',(2,3,4,0,192,33-count,count,16,192)),None))
        for count in (0,33,63): rejected(lambda:enc(Cmd('GEMM',(2,3,4,0,192,0,count,16,192)),None))
    for count in selected_counts():
        for op,banks in [('RMSNORM',(0,3,2)),('ADD',(0,1,5)),('SILU_MUL',(8,9,10)),('ROPE',(4,7))]:
            cmd=Cmd(op,(*banks,count));record=enc(cmd,None)
            assert record&((1<<112)-1)==count and dec(record,None)==cmd
        for op,banks in [('ATTN_SCORE',(4,8,10)),('ATTN_VALUE',(10,9,11)),('SOFTMAX',(10,))]:
            cmd=Cmd(op,(*banks,7,count,7+count));record=enc(cmd,None)
            assert record&((1<<112)-1)==(7<<17)|(count<<11)|(7+count)
            assert dec(record,None)==cmd
        p=ns['build_block']([0]*count,0,True)
        assert len(p.chunks)>=4 and all(c[-1].op=='END' for c in p.chunks)
        for chunk in p.chunks:
            for cmd in chunk:
                if cmd.op=='GEMM':
                    r=enc(cmd,None);assert (r>>19)&63==(cmd.args[6] if baseline else cmd.args[6]-1);assert dec(r,None)==cmd
    return {'roundtrips':count_tests,'all_30_layers_generated':True,'unrelated_count_formats':True,'scope':'actual codec and semantic generator; numerical interpreter checked separately'}

def c_gate(root,out,baseline):
    inc=root/DESIGN/'full_model_board_probe'; details={}
    for macro in (False,True):
        exe=out/('c_macro' if macro else 'c_direct')
        cmd=['cc','-std=c11','-O0','-I',inc,FIX/'c_probe.c','-o',exe]
        if macro:cmd.insert(1,'-DUSE_GEMM_TILES')
        run(cmd,out,out/f'{exe.name}_compile.log')
        checked=0
        for count in ((1,2,8,16,31,32) if PHASE!='hidden' else (3,7,15,17,29,30)):
            text=run([exe,count,0,0],out,out/f'{exe.name}_m{count}.log')
            layers=[s for s in text.splitlines() if s.startswith('L')];assert layers==[f'L{i}' for i in range(30)]
            dense=0
            for s in text.splitlines():
                if len(s)!=32:continue
                try:r=int(s,16)
                except ValueError:continue
                op=r>>124;dst=(r>>112)&15;p=r&((1<<112)-1)
                if op in (3,12):
                    logical=1 if dst==12 else count
                    shift=41 if op==12 else 19
                    assert (p>>shift)&63==(logical if baseline else logical-1),(macro,count,s)
                    dense+=1
                if op in (4,5,9,10):assert p==count
                if op in (6,7,8):assert (p>>11)&63==count
            assert dense>200
            checked+=dense
        if not baseline:
            for count,start in [(0,0),(33,0),(1,32),(32,1)]:
                text=run([exe,count,start,1],out,out/f'{exe.name}_invalid_{count}_{start}.log')
                assert 'RC=-1 SEEN=0' in text,'generator must reject before emitting DMA/compute'
        details[exe.name]={'dense_records_checked':checked}
    return details

def rtl_gate(root,out,baseline,binpath):
    rtl=root/DESIGN/'rtl'; details={}
    for top,fixture,sources in [
      ('t03_dispatcher','dispatcher.sv',['isa_command_dispatcher.sv','bank_ownership_table.sv']),
      ('t03_executor','executor.sv',['smollm2_gemm_systolic_wide_executor.sv'])]:
        work=out/top;work.mkdir(parents=True,exist_ok=True)
        run([binpath/'xvlog','--sv',*[(root/'ip/infrastructure/bank_ownership_table/rtl'/s if s=='bank_ownership_table.sv' else rtl/s) for s in sources],FIX/fixture],work,work/'compile.log')
        run([binpath/'xelab',top,'-s',top],work,work/'elaborate.log',600)
        cmd=[binpath/'xsim',top,'-runall','-testplusarg',PHASE]
        if baseline:cmd+=['-testplusarg','baseline']
        text=run(cmd,work,work/'simulate.log',600)
        assert ('T03_DISPATCHER_PASS' if top=='t03_dispatcher' else 'T03_EXECUTOR_PASS') in text and 'Fatal:' not in text
        details[top]={'passed':True,'log':str(work/'simulate.log')}
    return details

def main():
    p=argparse.ArgumentParser();p.add_argument('--candidate-root',type=pathlib.Path,required=True);p.add_argument('--out',type=pathlib.Path,required=True);p.add_argument('--baseline-mode',action='store_true');p.add_argument('--python-executable',type=pathlib.Path,default=pathlib.Path('/home/shmin/.conda/envs/shmin/bin/python'));p.add_argument('--phase',choices=['public','hidden','all'],default='all');p.add_argument('--skip-rtl',action='store_true');p.add_argument('--vivado-bin',type=pathlib.Path,default=pathlib.Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin'))
    a=p.parse_args();
    for line in (FIX/'SHA256SUMS').read_text().splitlines():
        expected,relative=line.split('  ',1)
        actual=hashlib.sha256((BASE/relative).read_bytes()).hexdigest()
        if actual!=expected: raise SystemExit('Evaluator integrity mismatch: '+relative)
    global PHASE;PHASE=a.phase;root=a.candidate_root.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    result={'task':'T03','baseline_mode':a.baseline_mode,'phase':a.phase,'candidate_root':str(root),'gates':{},'passed':False,'limits':['No board or synthesis signoff.','Full-model numerical interpreter qualification is supplied by common evaluator, not this isolated ISA evaluator.','Dispatcher uses an independent completion responder; executor is simulated separately.']}
    result['source_sha256']={str(f):hashlib.sha256((root/f).read_bytes()).hexdigest() for f in [PROTO,DESIGN/'full_model_board_probe/program.c',DESIGN/'rtl/isa_command_dispatcher.sv',DESIGN/'rtl/smollm2_gemm_systolic_wide_executor.sv',DESIGN/'full_model_board_probe/program.h',DESIGN/'full_model_board_probe/address_map.h',pathlib.Path('ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv')]}
    for name,fn in [('python',lambda:python_gate(root,a.baseline_mode)),('numeric_interpreter',lambda:json.loads(run([a.python_executable,BASE/'scripts/t03_numeric.py','--candidate-root',root,'--phase',a.phase],out,out/'numeric_interpreter.log').strip().splitlines()[-1])),('ps_c',lambda:c_gate(root,out,a.baseline_mode)),('rtl',lambda:rtl_gate(root,out,a.baseline_mode,a.vivado_bin))]:
        if name=='rtl' and a.skip_rtl:result['gates'][name]={'status':'NOT_RUN'};continue
        try: result['gates'][name]={'status':'PASS','details':fn()}
        except Exception as e:result['gates'][name]={'status':'FAIL','error':repr(e)}
        print(name,result['gates'][name]['status'],flush=True)
    result['passed']=all(g['status']=='PASS' for g in result['gates'].values())
    (out/'result.json').write_text(json.dumps(result,indent=2)+'\n'); print(json.dumps({'passed':result['passed'],'result':str(out/'result.json')}))
    return 0 if result['passed'] else 1
if __name__=='__main__':sys.exit(main())
