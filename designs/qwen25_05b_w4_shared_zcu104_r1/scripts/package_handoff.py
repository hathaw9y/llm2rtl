#!/usr/bin/env python3
"""Package already routed artifacts; neither synthesizes nor touches a board."""
import argparse,hashlib,json,shutil,zipfile,xml.etree.ElementTree as ET
from pathlib import Path
from check_board_reset import check as check_reset
BASE=Path(__file__).resolve().parents[1]
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for block in iter(lambda:f.read(1048576),b''):h.update(block)
 return h.hexdigest()
def tcl(p):return '{'+str(p.resolve()).replace('\\','/')+'}'
def main():
 p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);p.add_argument('--audit',type=Path,required=True);p.add_argument('--data',type=Path,required=True);p.add_argument('--firmware',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
 build=a.build.resolve();data=a.data.resolve();firmware=a.firmware.resolve();out=a.out.resolve()
 if out.exists():raise RuntimeError('Fresh handoff directory required')
 result=(build/'routed_result.txt').read_text();values=dict(line.split('=',1) for line in result.splitlines() if '=' in line)
 if values.get('part')!='xczu7ev-ffvc1156-2-e' or values.get('nominal_PL_clock_MHz')!='200':raise ValueError('Wrong hardware contract')
 if any(float(values[k])<0 for k in ['setup_slack_ns','hold_slack_ns']):raise ValueError('Integrated timing failed')
 invocation=json.loads((build/'invocation.json').read_text())
 if invocation['returncode']!=0:raise ValueError('Board build failed')
 reset_check=check_reset(build/'qwen.hwh')
 audit=a.audit.resolve();audit_result=json.loads((audit/'result.json').read_text())
 if audit_result['status']!='passed_routed_200MHz_clock_timing_audit' or audit_result['routed_DCP_sha256']!=sha(build/'routed.dcp'):raise ValueError('Matching setup/hold/pulse-width/clock/DRC audit missing')
 artifacts=[build/n for n in ['qwen.bit','qwen.hwh','qwen.xsa','timing_summary.rpt','utilization.rpt','drc.rpt','clocks.rpt','routed_result.txt','clock_configuration.txt','manifest.json']]
 artifacts+=[audit/n for n in ['result.json','timing_summary.rpt','clocks.rpt','drc.rpt','check_timing.rpt','audit_result.txt']]
 elfs=list(firmware.glob('*.elf'))
 if len(elfs)!=1:raise ValueError('Exactly one ELF required')
 artifacts+=elfs+[firmware/'manifest.json',data/'manifest.json',data/'DDR_layout.json',data/'model_ddr.bin']+list(data.glob('*logits.bin'))+list(data.glob('*KV_valid_prefix.bin'))
 dm=json.loads((data/'manifest.json').read_text());fm=json.loads((firmware/'manifest.json').read_text())
 bm=json.loads((build/'manifest.json').read_text())
 profile_key=str((BASE/'hardware_profile.json').relative_to(BASE.parents[1]))
 if fm.get('target_PL_clock_MHz')!=200 or fm.get('hardware_profile_sha256')!=bm['original_sources_sha256'].get(profile_key):raise ValueError('Firmware and board hardware-profile identity mismatch')
 if sha(data/'model_ddr.bin')!=dm['DDR_image_sha256'] or sha(elfs[0])!=fm['ELF_sha256'] or sha(data/'DDR_layout.json')!=fm['DDR_layout_sha256']:raise ValueError('Firmware or data identity mismatch')
 out.mkdir(parents=True)
 with zipfile.ZipFile(build/'qwen.xsa') as z:
  bitnames=[n for n in z.namelist() if n.endswith('.bit')];hwhnames=[n for n in z.namelist() if n.endswith('.hwh')];initnames=[n for n in z.namelist() if n.endswith('psu_init.tcl')]
  if len(bitnames)!=1 or hashlib.sha256(z.read(bitnames[0])).hexdigest()!=sha(build/'qwen.bit'):raise ValueError('XSA/BIT mismatch')
  # SmartConnect exports child HWHs in addition to the top-level system.
  top_hwh=[n for n in hwhnames if Path(n).name=='qwen_system.hwh']
  if len(top_hwh)!=1:raise ValueError('Unique top-level XSA HWH missing')
  hwh=z.read(top_hwh[0]);system=ET.fromstring(hwh).find('SYSTEMINFO')
  if system is None or system.get('NAME')!='qwen_system':raise ValueError('Wrong top-level HWH system')
  if hashlib.sha256(hwh).hexdigest()!=sha(build/'qwen.hwh'):raise ValueError('XSA/HWH mismatch')
  if len(initnames)!=1:raise ValueError('Matching XSA psu_init.tcl missing')
  (out/'psu_init.tcl').write_bytes(z.read(initnames[0]))
 manifest={'status':'routed_artifact_handoff','physical_board_execution':'not_performed','hardware':values,'artifact_sha256':{str(f):sha(f) for f in artifacts},'psu_init_sha256':sha(out/'psu_init.tcl'),'model_scope':'prefill [9707,11], decode [151643], prefix2, full24layer logits/KV','limitations':['No full-model RTL simulation proof in bounded packet evidence','Original BF16 W4 quality probe failed','prefill512 KV tolerance failed','decode1024 uses reference-seeded prefix1023']}
 if fm.get('model_load'):manifest['model_load']=fm['model_load']
 (out/'artifact_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 (out/'board_reset_check.json').write_text(json.dumps(reset_check,indent=2)+'\n')
 model_transfer='' if fm.get('model_load') else f'dow -data {tcl(data/"model_ddr.bin")} 0x10000000\n'
 (out/'load_board.tcl').write_text(f'''# USER EXECUTION ONLY. Cold power/reset, JTAG boot, matching ZCU104.
connect
targets -set -filter {{name =~ "APU*"}}
rst -system -stop
after 2000
fpga -file {tcl(build/'qwen.bit')}
source {tcl(out/'psu_init.tcl')}
psu_init
if {{[llength [info commands psu_post_config]]}} {{psu_post_config}}
if {{[llength [info commands psu_ps_pl_isolation_removal]]}} {{psu_ps_pl_isolation_removal}}
if {{[llength [info commands psu_ps_pl_reset_config]]}} {{psu_ps_pl_reset_config}}
targets -set -filter {{name =~ "PSU*"}}
set qwen_profile_value [mrd -force -value 0xA0010018]
if {{$qwen_profile_value != 0x51574E31}} {{error "QWEN PL profile mismatch: $qwen_profile_value"}}
set qwen_status_value [mrd -force -value 0xA0010004]
if {{$qwen_status_value & 0xD}} {{error "QWEN PL not idle after board reset: $qwen_status_value"}}
puts "PL_CONTROL_PREFLIGHT_PASS profile=QWN1 reset_released"
targets -set -filter {{name =~ "Cortex-A53 #0*"}}
rst -processor -stop -clear-registers -isa A64
configparams force-mem-access 1
{model_transfer}dow {tcl(elfs[0])}
configparams force-mem-access 0
con
puts "Wait for UART1 HANDOFF_DONE before sourcing dump_board.tcl."
''')
 dumps=out/'dumps'
 (out/'dump_board.tcl').write_text(f'''# Run in the same XSCT session AFTER UART1 HANDOFF_DONE.
targets -set -filter {{name =~ "Cortex-A53 #0*"}}
stop
file mkdir {tcl(dumps)}
mrd -bin -size b -file {tcl(dumps/'prefill_logits.bin')} 0x08000000 303872
mrd -bin -size b -file {tcl(dumps/'prefill_KV_valid_prefix.bin')} 0x08050000 24576
mrd -bin -size b -file {tcl(dumps/'decode_logits.bin')} 0x08100000 303872
mrd -bin -size b -file {tcl(dumps/'decode_KV_valid_prefix.bin')} 0x08150000 36864
puts "Save UART1 output as uart.log and run host compare_board.py."
''')
 shutil.copyfile(BASE/'scripts/compare_board.py',out/'compare_board.py')
 print(out/'artifact_manifest.json')
if __name__=='__main__':main()
