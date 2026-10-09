if {[llength $argv]!=2} {error "usage: run_ooc_synthesis.tcl <evidence_dir> <work_dir>"}
set ev [file normalize [lindex $argv 0]]
set work [file normalize [lindex $argv 1]]
if {[file exists $work]} {error "fresh work directory required: $work"}
file mkdir $ev
file mkdir $work
set root [file normalize [file join [file dirname [info script]] ".."]]
create_project bank_port_router_ooc [file join $work project] -part xczu7ev-ffvc1156-2-e -force
read_verilog -sv [file join $root rtl bank_port_router.sv]
set_property top bank_port_router [current_fileset]
synth_design -top bank_port_router -part xczu7ev-ffvc1156-2-e -mode out_of_context
if {[llength [get_cells -hier -filter {IS_BLACKBOX==1}]]!=0} {error "black boxes present"}
create_clock -name aclk -period 5.000 [get_ports aclk]
set_property HD.CLK_SRC [lindex [get_sites -filter {SITE_TYPE =~ BUFG*}] 0] [get_ports aclk]
set ins [get_ports -filter {DIRECTION==IN && NAME!=aclk}]
set outs [all_outputs]
set_input_delay -clock aclk -max 0.500 $ins
set_input_delay -clock aclk -min 0.000 $ins
set_output_delay -clock aclk -max 0.500 $outs
set_output_delay -clock aclk -min 0.000 $outs
set_false_path -hold -from $ins
set_false_path -hold -to $outs
write_checkpoint -force [file join $ev bank_port_router_post_synth.dcp]
report_utilization -file [file join $ev utilization_post_synth.rpt]
report_timing_summary -delay_type min_max -check_timing_verbose -file [file join $ev timing_post_synth.rpt]
report_drc -file [file join $ev drc_post_synth.rpt]
report_methodology -file [file join $ev methodology_post_synth.rpt]
if {[llength [get_timing_paths -delay_type max -max_paths 1]]==0} {error "no setup path"}
puts "PASS: bank_port_router Vivado 2025.2 OOC synthesis"
exit
