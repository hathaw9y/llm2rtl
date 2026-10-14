#!/usr/bin/env python3
"""Fresh source-frozen XSIM and post-synthesis OOC checks for registered_capture."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import sys
from run_infrastructure_sim import run_command, decoded_xsim

ROOT = Path(__file__).resolve().parents[1]
REV = ROOT / 'designs/infrastructure_registered_capture_r1'
SOURCES = [ROOT/'ip/infrastructure/utils/registered_capture.sv',
           ROOT/'ip/infrastructure/examples/registered_capture_example.sv']
TB = ROOT/'ip/infrastructure/tb/tb_registered_capture.sv'

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p, value): p.write_text(json.dumps(value, indent=2)+'\n')

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--vivado-bin', type=Path, default=Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin'))
    args = ap.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy(); env['XILINX_VIVADO'] = str(args.vivado_bin.parent)
    result = {'status':'running','scope':'utility plus actual packed example; post-synthesis OOC only; no routed, board or accelerator proof', 'cases':[], 'commands':[]}
    originals = [*SOURCES, TB, Path(__file__).resolve(), ROOT/'scripts/run_infrastructure_sim.py', REV/'module_packet.json', REV/'structure_contract.json']
    frozen = {}
    for p in originals:
        dest = out/'source_snapshot'/p.relative_to(ROOT)
        dest.parent.mkdir(parents=True, exist_ok=True); dest.write_bytes(p.read_bytes())
        frozen[str(p)] = {'sha256':sha(p),'snapshot':str(dest)}
    result['inputs'] = frozen; save(out/'result.json', result)
    def command(argv, wd, name, timeout=180):
        rec = run_command(argv,wd,wd/name,env,timeout)
        result['commands'].append(rec); save(out/'result.json',result)
        if not rec['passed']: raise RuntimeError(f'{name} failed: {rec}')
        return (wd/name).read_text(errors='replace')
    try:
        result['version'] = command([args.vivado_bin/'vivado','-version'],out,'version.log')
        for backend in (0,1):
            for width,group in ((1,1),(32,32),(33,32),(136,17),(438,32)):
                work=out/f'xsim_w{width}_g{group}_b{backend}'; work.mkdir()
                marker=f'PASS registered_capture width={width} group={group} backend={backend}'
                command([args.vivado_bin/'xvlog','--sv',*SOURCES,TB],work,'compile.log')
                glbl=args.vivado_bin.parent/'data/verilog/src/glbl.v'
                command([args.vivado_bin/'xvlog',glbl],work,'glbl.log')
                command([args.vivado_bin/'xelab','tb_registered_capture','glbl','-L','unisims_ver','-s','capture_sim','-timescale','1ns/1ps','-generic_top',f'DATA_WIDTH={width}','-generic_top',f'GROUP_WIDTH={group}','-generic_top',f'USE_XILINX_FDRE={backend}'],work,'elaborate.log')
                transcript=command([sys.executable,ROOT/'ip/infrastructure/scripts/run_xsimk.py',work/'xsim.dir/capture_sim/xsimk',marker],work,'simulation.log')
                decoded=decoded_xsim(transcript); (work/'simulation.stdout').write_text(decoded)
                if decoded.splitlines().count(marker)!=1: raise RuntimeError('missing exact PASS')
                result['cases'].append({'width':width,'group':group,'backend':backend,'status':'passed','marker':marker,'stdout':str(work/'simulation.stdout')})
                save(out/'result.json',result)
                print(marker,flush=True)
        work=out/'ooc'; work.mkdir()
        tcl=work/'run.tcl'
        tcl.write_text('''set_param general.maxThreads 4
create_project -in_memory -part xczu7ev-ffvc1156-2-e
read_verilog -sv {SRC0}
read_verilog -sv {SRC1}
set xdc [open capture.xdc w]
puts $xdc {create_clock -name capture_clk -period 5.000 [get_ports aclk]}
puts $xdc {set_property HD.CLK_SRC BUFGCE_DIV_X0Y16 [get_ports aclk]}
puts $xdc {set_input_delay -clock capture_clk -min 1.0 [get_ports -filter {DIRECTION == IN && NAME != aclk}]}
puts $xdc {set_input_delay -clock capture_clk -max 1.0 [get_ports -filter {DIRECTION == IN && NAME != aclk}]}
puts $xdc {set_output_delay -clock capture_clk -min 1.0 [get_ports -filter {DIRECTION == OUT}]}
puts $xdc {set_output_delay -clock capture_clk -max 1.0 [get_ports -filter {DIRECTION == OUT}]}
close $xdc
read_xdc capture.xdc
synth_design -top registered_capture_example -part xczu7ev-ffvc1156-2-e -mode out_of_context
write_checkpoint -force synthesized.dcp
report_clocks -file clocks.rpt
report_utilization -file utilization.rpt
report_timing_summary -delay_type min_max -check_timing_verbose -report_unconstrained -file timing_summary.rpt
check_timing -verbose -file check_timing.rpt
report_drc -file drc.rpt
report_methodology -file methodology.rpt
if {[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]] != 0} {error "blackbox found"}
set fp [open binding.tsv w]
puts $fp "group\\tce_driver\\tloads\\tce_path_slack\\treset_path_slack\\tdata_path_slack"
set groups [get_cells -hier -filter {NAME =~ *u_local_ce && REF_NAME == FDRE}]
if {[llength $groups] != 5} {error "expected five protected localCE groups"}
set bits [open bit_binding.tsv w]
puts $bits "capture\\tprepareQ\\tdataD\\treset_start\\tce_driver"
set total 0
foreach cell $groups {
 set q [get_pins -of_objects $cell -filter {REF_PIN_NAME == Q}]
 set net [get_nets -segments -of_objects $q]
 set loads [get_pins -leaf -of_objects $net -filter {DIRECTION == IN}]
 set drivers [get_pins -leaf -of_objects $net -filter {DIRECTION == OUT}]
 if {[llength $drivers] != 1 || [get_property NAME $drivers] ne [get_property NAME $q]} {error "CE net unique driver mismatch"}
 set count [llength $loads]
 if {$count < 1 || $count > 32} {error "invalid CE fanout $count"}
 foreach pin $loads {
  if {[get_property REF_PIN_NAME $pin] ne "CE"} {error "CEQ has nonCE load $pin"}
  set leaf [get_cells -of_objects $pin]
  if {[get_property REF_NAME $leaf] ne "FDRE" || ![string match *u_capture [get_property NAME $leaf]]} {error "CE target is not capture FDRE"}
  set r [get_pins -of_objects $leaf -filter {REF_PIN_NAME == R}]
  set d [get_pins -of_objects $leaf -filter {REF_PIN_NAME == D}]
  set dp [get_timing_paths -to $d -max_paths 1]
  set rp [get_timing_paths -to $r -max_paths 1]
  if {[llength $dp] == 0 || [llength $rp] == 0} {error "empty data/reset path"}
  set expected [string map {u_capture u_prepare} [get_property NAME $leaf]]
  append expected /Q
  set actual [get_property STARTPOINT_PIN $dp]
  if {$actual ne $expected} {error "data D prepared bit mismatch $actual $expected"}
  if {[get_property STARTPOINT_PIN $rp] ne "aresetn"} {error "R path does not start at aresetn"}
  puts $bits "[get_property NAME $leaf]\\t$actual\\t[get_property NAME $d]\\t[get_property STARTPOINT_PIN $rp]\\t[get_property NAME $q]"
  report_timing -of_objects $dp -append -file data_paths.rpt
  report_timing -of_objects $rp -append -file reset_paths.rpt
 }
 set cp [get_timing_paths -from $q -to $loads -max_paths 1]
 if {[llength $cp] == 0} {error "empty CEQ to CE path"}
 report_timing -of_objects $cp -append -file ce_paths.rpt
 puts $fp "[get_property NAME $cell]\\t[get_property NAME $q]\\t$count\\t[get_property SLACK $cp]\\t[get_property SLACK $rp]\\t[get_property SLACK $dp]"
 incr total $count
}
close $fp
close $bits
if {$total != 136} {error "capture bit count mismatch"}
set fp [open counts.txt w]
puts $fp "local_ce_groups=[llength $groups] capture_bits=$total blackboxes=0"
close $fp
puts "PASS registered_capture OOC bindings"
exit
'''.replace('{SRC0}',str(SOURCES[0])).replace('{SRC1}',str(SOURCES[1])))
        result['ooc_script_sha256']=sha(tcl)
        transcript=command([args.vivado_bin/'vivado','-mode','batch','-source',tcl,'-nojournal'],work,'vivado.log',240)
        if transcript.splitlines().count('PASS registered_capture OOC bindings')!=1: raise RuntimeError('missing OOC marker')
        result['ooc']={'status':'completed','stage':'post-synthesis','reports':str(work),'bindings':str(work/'binding.tsv')}
        summary=(work/'timing_summary.rpt').read_text()
        rows=re.findall(r'^\s*(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)\s*$',summary,re.M)
        if not rows: raise RuntimeError('missing numeric setup/hold/pulse summary')
        values=rows[0]
        result['timing']={'WNS':float(values[0]),'TNS':float(values[1]),'setup_failing':int(values[2]),'WHS':float(values[4]),'THS':float(values[5]),'hold_failing':int(values[6]),'WPWS':float(values[8]),'TPWS':float(values[9]),'pulse_failing':int(values[10]),'stage':'post-synthesis','period_ns':5.0}
        if any(float(values[i])<0 for i in (0,4,8)) or any(int(values[i])!=0 for i in (2,6,10)):
            raise RuntimeError('setup/hold/pulse timing gate failed')
        checks=(work/'check_timing.rpt').read_text()
        check_counts={name:int(count) for name,count in re.findall(r'checking\s+(\w+)\s+\((\d+)\)',checks)}
        result['timing_checks']=check_counts
        required=('no_clock','unconstrained_internal_endpoints','loops','latch_loops')
        if any(name not in check_counts or check_counts[name] for name in required):
            raise RuntimeError('missing or failing internal timing checks')
        if 'Timing constraints are not met' in summary: raise RuntimeError('timing summary failure')
        result['status']='passed' 
    except Exception as e:
        result['status']='failed'; result['error']=str(e)
        print(str(e),flush=True)
    result['changed_inputs']=[p for p,v in frozen.items() if sha(Path(p))!=v['sha256']]
    if result['changed_inputs']: result['status']='failed'
    save(out/'result.json',result)
    return 0 if result['status']=='passed' else 1
if __name__=='__main__': sys.exit(main())
