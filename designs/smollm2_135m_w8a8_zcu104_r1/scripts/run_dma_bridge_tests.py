#!/usr/bin/env python3
"""Actual pinned mover/adapters and XSIM native/control BFMs; no substitute RTL."""
import argparse,hashlib,json,pathlib,subprocess,sys
p=argparse.ArgumentParser();p.add_argument('--run-dir',required=True);a=p.parse_args()
D=pathlib.Path(__file__).resolve().parents[1];root=D.parents[1];v=pathlib.Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin');run=pathlib.Path(a.run_dir).resolve();run.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(root/'scripts'))
from infrastructure_sources import resolve_reference
names=['datamover_engine_pkg','datamover_engine','mm2s_channel','s2mm_channel','datamover_command_queue','status_decoder','fifo','mm2s_adapter','s2mm_adapter','axis_width_converter','axis_width_up_converter','axis_width_down_converter','pipeline']
sources=[resolve_reference(f'ip/infrastructure/datamover_engine/rtl/{n}.sv',root=root) for n in names]+[D/'rtl/smollm2_dma_transaction_bridge.sv',D/'tb/dma_bridge_tb.sv']
pins={str(s):hashlib.sha256(s.read_bytes()).hexdigest() for s in sources};(run/'source_pins.json').write_text(json.dumps(pins,indent=2));(run/'source.sv').write_bytes(sources[-2].read_bytes());(run/'testbench.sv').write_bytes(sources[-1].read_bytes())
commands=[('compile',[str(v/'xvlog'),'-sv',*map(str,sources)]),('elaborate',[str(v/'xelab'),'dma_bridge_tb','-s','dma_bridge_tb','--timescale','1ns/1ps']),('simulation',[sys.executable,str(root/'ip/infrastructure/archive/pre_physical_20261012/snapshot/ip/infrastructure/datamover_engine/scripts/run_xsimk.py'),str(run/'xsim.dir/dma_bridge_tb/xsimk'),'DMA_BRIDGE_PASS'])]
results=[]
for name,cmd in commands:
 with (run/(name+'.log')).open('w') as f:ret=subprocess.run(cmd,cwd=run,stdout=f,stderr=subprocess.STDOUT).returncode
 results.append({'stage':name,'argv':cmd,'exit_code':ret});(run/'commands.json').write_text(json.dumps(results,indent=2));print(name,ret,flush=True)
 if ret:print((run/(name+'.log')).read_text()[-3000:]);sys.exit(ret)
assert pins=={str(s):hashlib.sha256(s.read_bytes()).hexdigest() for s in sources}
print((run/'simulation.log').read_text()[-1800:])
