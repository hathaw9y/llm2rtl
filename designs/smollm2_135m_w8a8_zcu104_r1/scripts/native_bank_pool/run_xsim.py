import pathlib,subprocess,json,sys,hashlib
B=pathlib.Path(__file__).resolve().parents[2];E=B/'evidence/native_bank_pool';run=E/(sys.argv[1] if len(sys.argv)>1 else 'xsim01');run.mkdir(exist_ok=True);X=pathlib.Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin')
sources=[B/'rtl'/n for n in ['bram_bank.sv','uram_bank.sv','smollm2_bank_payload.sv','smollm2_bank_coverage.sv','smollm2_native_bank_pool.sv']];commands=[]
for stage,args in [('compile',[str(X/'xvlog'),'-sv',*[str(p) for p in sources],str(E/'tb.sv')]),('elaborate',[str(X/'xelab'),'tb','-L','xpm','-s','native_leaf_tb']),('simulate',['python3',str(B.parents[1]/'ip/infrastructure/archive/pre_physical_20261012/snapshot/ip/infrastructure/datamover_engine/scripts/run_xsimk.py'),str(run/'xsim.dir/native_leaf_tb/xsimk'),'PASS_NATIVE_BANK_POOL_ACTUAL_XPM'])]:
 with (run/(stage+'.raw.log')).open('w') as log:r=subprocess.run(args,cwd=run,stdout=log,stderr=subprocess.STDOUT,text=True)
 commands.append({'stage':stage,'argv':args,'cwd':str(run),'actual_exit_code':r.returncode});(run/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
 print(stage,r.returncode,flush=True)
 if r.returncode:print((run/(stage+'.raw.log')).read_text()[-5000:]);sys.exit(r.returncode)
raw=(run/'simulate.raw.log').read_text();decoded=[]
for line in raw.splitlines():
 if line.startswith('@'):
  try:decoded.append(json.loads(line[1:]))
  except json.JSONDecodeError:pass
text=''.join(decoded);(run/'executed_display.log').write_text(text)
assert 'PASS_NATIVE_BANK_POOL_ACTUAL_XPM' in text.splitlines(),raw[-5000:]
(run/'report.json').write_text(json.dumps({'status':'ACTUAL_XPM_SELFTEST_PASS','source_sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},'commands':commands,'testbench_sha256':hashlib.sha256((E/'tb.sv').read_bytes()).hexdigest(),'marker':'PASS_NATIVE_BANK_POOL_ACTUAL_XPM'},indent=2)+'\n');print(raw[-1000:])
