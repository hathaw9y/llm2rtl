#!/usr/bin/env python3
"""Supervisor synthesis audit. Does not trust candidate scripts' PASS claims.

Defaults: production wide executor and production control-fabric source closure
(dispatcher, ownership, tensor tracker, DMA and banks). Optional board project is
created using candidate create_perf128_board_probe_100mhz.tcl, redirected under
--out, and only synthesis is launched. OOC timing is not routed timing signoff.
--prepare-only validates source existence and writes runnable Tcl, with NOT_RUN
results. Existing/stale reports are never used to promote an unexecuted audit.
"""
import argparse
import hashlib
import json
import math
import re
import subprocess
import time
from pathlib import Path

PART='xczu7ev-ffvc1156-2-e'
DESIGN='designs/smollm2_135m_bf16_zcu104_r1'
CAPACITY={'LUT':230400,'FF':460800,'DSP':1728,'BRAM':312,'URAM':96}
LABELS={'LUT':'CLB LUTs','FF':'CLB Registers','DSP':'DSPs','BRAM':'Block RAM Tile','URAM':'URAM'}
DMA=['datamover_engine_pkg','fifo','pipeline','axis_width_up_converter',
     'axis_width_down_converter','axis_width_converter','mm2s_adapter',
     's2mm_adapter','datamover_command_queue','mm2s_channel','s2mm_channel',
     'datamover_engine','bram_bank','uram_bank']
FABRIC=['smollm2_bank_port_router_wide','smollm2_bank_memories_wide',
        'smollm2_bank_subsystem_wide','smollm2_dma_bank_bridge',
        'smollm2_dma_engine_link','bank_tensor_state_tracker',
        'isa_command_dispatcher','smollm2_dma_control_fabric_wide']


def tcl_quote(value):
    # Preserve paths without allowing Tcl substitutions or command execution.
    return '"'+str(value).replace('\\','\\\\').replace('"','\\"').replace('$','\\$').replace('[','\\[').replace(']','\\]')+'"'


def source_hash(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def utilization(text):
    values={}
    for resource,label in LABELS.items():
        m=re.search(r'^\|\s*'+re.escape(label)+r'\s*\|\s*([\d,.]+)\s*\|',text,re.M)
        if m:values[resource]=float(m[1].replace(',',''))
    if set(values)!=set(CAPACITY):raise ValueError('Missing utilization rows: '+str(set(CAPACITY)-set(values)))
    if not all(math.isfinite(v) and v>=0 for v in values.values()):raise ValueError('Invalid utilization value')
    return values


def summary_wns(text):
    m=re.search(r'WNS\(ns\)[^\n]*\n\s*[-\s]+\n\s*([-+]?\d+(?:\.\d+)?)',text)
    if not m:raise ValueError('Timing summary WNS is absent')
    return float(m[1])


def timing_counts(text):
    values={}
    for label in ['no_clock','unconstrained_internal_endpoints','multiple_clock']:
        found=re.findall(r'checking\s+'+label+r'\s*\((\d+)\)',text)
        if not found:raise ValueError('Missing check_timing count: '+label)
        values[label]=max(map(int,found))
    # Boundary IO delays are intentionally absent for OOC; record rather than
    # interpreting them as constrained end-to-end interface timing.
    for label in ['no_input_delay','no_output_delay']:
        found=re.findall(r'checking\s+'+label+r'\s*\((\d+)\)',text)
        values[label]=max(map(int,found)) if found else None
    return values


REPORT_TCL=r'''
report_utilization -file utilization.rpt
report_timing_summary -report_unconstrained -check_timing_verbose -file timing_summary.rpt
report_timing -delay_type max -max_paths 20 -path_type full_clock_expanded -file setup_paths.rpt
report_clocks -file clocks.rpt
check_timing -verbose -file check_timing.rpt
report_drc -file drc.rpt
set metric_file [open metrics.tsv w]
puts $metric_file "part\t[get_property PART [current_design]]"
set path [get_timing_paths -setup -max_paths 1]
if {[llength $path] == 1} {
    puts $metric_file "setup_slack_ns\t[get_property SLACK [lindex $path 0]]"
} else {puts $metric_file "setup_slack_ns\tABSENT"}
puts $metric_file "blackboxes\t[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]"
foreach clock [get_clocks] {
    puts $metric_file "clock\t[get_property NAME $clock]\t[get_property PERIOD $clock]"
}
close $metric_file
write_checkpoint -force synthesized.dcp
'''


def parse_reports(directory,kind):
    required=['utilization.rpt','timing_summary.rpt','setup_paths.rpt','clocks.rpt','check_timing.rpt','drc.rpt','metrics.tsv']
    absent=[name for name in required if not (directory/name).is_file()]
    if absent:raise ValueError('Missing supervisor reports: '+', '.join(absent))
    metrics={};clocks=[]
    for line in (directory/'metrics.tsv').read_text().splitlines():
        parts=line.split('\t')
        if parts[0]=='clock':clocks.append({'name':parts[1],'period_ns':float(parts[2])})
        elif len(parts)==2:metrics[parts[0]]=parts[1]
    if metrics.get('part')!=PART:raise ValueError('Unexpected synthesized device: '+str(metrics.get('part')))
    slack=float(metrics['setup_slack_ns']);wns=summary_wns((directory/'timing_summary.rpt').read_text())
    if not math.isfinite(slack) or abs(slack-wns)>0.002:raise ValueError('Setup-path slack and summary WNS disagree')
    counts=timing_counts((directory/'check_timing.rpt').read_text())
    used=utilization((directory/'utilization.rpt').read_text())
    fit=all(used[k]<=CAPACITY[k] for k in CAPACITY)
    if kind=='board':clock_ok=any(c['name']=='clk_pl_0' and abs(c['period_ns']-10)<0.001 for c in clocks)
    else:clock_ok=any(c['name']=='audit_aclk_100mhz' and abs(c['period_ns']-10)<0.001 for c in clocks)
    gates={'clock_100mhz':clock_ok,'constrained_internal_endpoints':counts['no_clock']==0 and counts['unconstrained_internal_endpoints']==0 and counts['multiple_clock']==0,
           'setup_nonnegative':slack>=0,'fits_device':fit,'no_blackboxes':int(metrics['blackboxes'])==0}
    return {'status':'PASS' if all(gates.values()) else 'FAIL','gates':gates,'setup_slack_ns':slack,'summary_wns_ns':wns,
            'resources':{k:{'used':used[k],'capacity':CAPACITY[k]} for k in CAPACITY},
            'clocks':clocks,'timing_checks':counts,'blackboxes':int(metrics['blackboxes']),
            'reports':{name:str(directory/name) for name in required},
            'scope':'Post-synthesis estimates, not placement/routing or hardware signoff.'}


def prepare_ooc(directory,top,sources,rtl_dir):
    directory.mkdir(parents=True,exist_ok=True)
    (directory/'clock.xdc').write_text('create_clock -name audit_aclk_100mhz -period 10.000 [get_ports aclk]\n')
    tcl='create_project -in_memory -part '+PART+'\n'
    for source in sources:tcl+='read_verilog -sv '+tcl_quote(source)+'\n'
    tcl+='set_property include_dirs [list '+tcl_quote(rtl_dir)+'] [get_filesets sources_1]\n'
    tcl+='add_files -fileset constrs_1 '+tcl_quote(directory/'clock.xdc')+'\n'
    tcl+='synth_design -mode out_of_context -flatten_hierarchy none -top '+top+' -part '+PART+'\n'+REPORT_TCL
    (directory/'audit.tcl').write_text(tcl)


def prepare_board(directory,create_script,jobs):
    directory.mkdir(parents=True,exist_ok=True)
    tcl='set ::env(SMOLLM2_PROFILE_BUILD_DIR) '+tcl_quote(directory/'project')+'\n'
    tcl+='source '+tcl_quote(create_script)+'\n'
    tcl+='if {[get_property PART [current_project]] ne "'+PART+'"} {error "wrong board part"}\n'
    tcl+='launch_runs synth_1 -jobs '+str(jobs)+'\nwait_on_run synth_1\n'
    tcl+='set status [get_property STATUS [get_runs synth_1]]\nif {![string match {*Complete*} $status]} {error "board synthesis failed: $status"}\n'
    tcl+='open_run synth_1\n'+REPORT_TCL
    (directory/'audit.tcl').write_text(tcl)


def execute(directory,vivado,timeout):
    # Empty fresh run directories prevent stale report acceptance.
    start=time.monotonic()
    with (directory/'vivado.log').open('w') as logfile:
        process=subprocess.run([vivado,'-mode','batch','-nojournal','-source',str(directory/'audit.tcl')],
                               cwd=directory,stdout=logfile,stderr=subprocess.STDOUT,timeout=timeout)
    if process.returncode:raise RuntimeError('Vivado exited '+str(process.returncode)+'; see '+str(directory/'vivado.log'))
    return time.monotonic()-start


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate-root',type=Path,required=True);parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--board-top',action='store_true');parser.add_argument('--prepare-only',action='store_true')
    parser.add_argument('--vivado',default='vivado');parser.add_argument('--jobs',type=int,default=4);parser.add_argument('--timeout',type=int,default=7200)
    args=parser.parse_args();candidate=args.candidate_root.resolve();out=args.out.resolve()
    if args.jobs<1 or args.timeout<1:parser.error('jobs and timeout must be positive')
    if out==candidate or candidate in out.parents:
        parser.error('--out must be outside the candidate source tree')
    if out.exists() and any(out.iterdir()):parser.error('--out must be empty/fresh; old reports cannot be reused')
    out.mkdir(parents=True,exist_ok=True)
    rtl=candidate/DESIGN/'rtl';ip=candidate/'ip/infrastructure';create=candidate/DESIGN/'scripts/create_perf128_board_probe_100mhz.tcl'
    fabric_sources=[ip/'datamover_engine/rtl'/f'{name}.sv' for name in DMA]+[ip/'bank_ownership_table/rtl/bank_ownership_table.sv']+[rtl/f'{name}.sv' for name in FABRIC]
    specs=[('wide_executor','smollm2_gemm_systolic_wide_executor',[rtl/'smollm2_gemm_systolic_wide_executor.sv']),
           ('dispatcher_ownership_closure','smollm2_dma_control_fabric_wide',fabric_sources)]
    report={'supervisor_sha256':source_hash(Path(__file__)), 'vivado_invocation':args.vivado, 'candidate_root':str(candidate),'out':str(out),'device':PART,'clock_mhz':100,'audits':{},'board_top':{'status':'NOT_RUN','reason':'--board-top not requested'},
            'limitations':['OOC input/output delays are not assigned; boundary interfaces are not signed off.','Synthesis setup/fit evidence does not establish routed timing, bitstream or hardware validity.','Board clock gate requires the production PS clock clk_pl_0 at 10ns; alternate clock naming requires supervisor review.']}
    # Record actual candidate production closure content; no candidate evidence read.
    inventory=set(path for _,_,sources in specs for path in sources)
    if args.board_top:
        inventory.add(create)
        inventory.update(rtl.glob('*.sv'));inventory.update(rtl.glob('*.v'));inventory.update(rtl.glob('*.svh'));inventory.update(rtl.glob('*.mem'))
    original={str(path):source_hash(path) for path in inventory if path.is_file()}
    report['source_sha256']=original
    try:
        for name,top,sources in specs:
            directory=out/name;missing=[str(path) for path in sources if not path.is_file()]
            if missing:report['audits'][name]={'status':'ERROR','missing_sources':missing};continue
            prepare_ooc(directory,top,sources,rtl)
            if args.prepare_only:report['audits'][name]={'status':'NOT_RUN','reason':'prepare-only','tcl':str(directory/'audit.tcl')};continue
            try:
                elapsed=execute(directory,args.vivado,args.timeout);result=parse_reports(directory,'ooc');result['elapsed_seconds']=elapsed;report['audits'][name]=result
            except Exception as error:report['audits'][name]={'status':'ERROR','reason':str(error),'log':str(directory/'vivado.log')}
        if args.board_top:
            directory=out/'board_top'
            if not create.is_file():report['board_top']={'status':'ERROR','reason':'candidate board creator absent','path':str(create)}
            else:
                prepare_board(directory,create,args.jobs)
                if args.prepare_only:report['board_top']={'status':'NOT_RUN','reason':'prepare-only','tcl':str(directory/'audit.tcl')}
                else:
                    try:
                        elapsed=execute(directory,args.vivado,args.timeout);result=parse_reports(directory,'board');result['elapsed_seconds']=elapsed;report['board_top']=result
                    except Exception as error:report['board_top']={'status':'ERROR','reason':str(error),'log':str(directory/'vivado.log')}
    finally:
        changed=[path for path,digest in original.items() if not Path(path).is_file() or source_hash(Path(path))!=digest]
        report['sources_unchanged']=not changed;report['changed_during_audit']=changed
        required=list(report['audits'].values())+([report['board_top']] if args.board_top else [])
        report['overall_status']='PASS' if required and all(item['status']=='PASS' for item in required) and not changed else ('NOT_RUN' if args.prepare_only and not changed and all(item['status']=='NOT_RUN' for item in required) else 'FAIL')
        (out/'audit_report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
    return 0 if report['overall_status']=='PASS' or (args.prepare_only and report['overall_status']=='NOT_RUN') else 1


if __name__=='__main__':raise SystemExit(main())
