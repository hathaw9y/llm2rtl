#!/usr/bin/env python3
"""Real vendor XPM command-memory test; plain xelab snapshot (no debug wrapper)."""
import argparse,pathlib,subprocess,json,hashlib,sys
p=argparse.ArgumentParser();p.add_argument('--run-dir',required=True);a=p.parse_args();D=pathlib.Path(__file__).resolve().parents[1];root=D.parents[1];v=pathlib.Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado');run=pathlib.Path(a.run_dir).resolve();run.mkdir(parents=True,exist_ok=True)
sources=[v/'data/ip/xpm/xpm_memory/hdl/xpm_memory.sv',root/'ip/infrastructure/datamover_engine/rtl/bram_bank.sv',D/'rtl/smollm2_command_bram.sv',D/'tb/command_bram_tb.sv'];pins={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources};(run/'source_pins.json').write_text(json.dumps(pins,indent=2));commands=[]
for name,argv in [('compile',[str(v/'bin/xvlog'),'-sv',*map(str,sources)]),('elaborate',[str(v/'bin/xelab'),'command_bram_tb','-s','command_bram_tb','--timescale','1ns/1ps']),('simulation',[sys.executable,str(root/'ip/infrastructure/datamover_engine/scripts/run_xsimk.py'),str(run/'xsim.dir/command_bram_tb/xsimk'),'COMMAND_BRAM_PASS'])]:
 with (run/(name+'.log')).open('w')as f:r=subprocess.run(argv,cwd=run,stdout=f,stderr=subprocess.STDOUT)
 commands.append({'stage':name,'argv':argv,'exit_code':r.returncode});(run/'commands.json').write_text(json.dumps(commands,indent=2));print(name,r.returncode,flush=True)
 if r.returncode:sys.exit(r.returncode)
assert pins=={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
print((run/'simulation.log').read_text()[-1500:])
