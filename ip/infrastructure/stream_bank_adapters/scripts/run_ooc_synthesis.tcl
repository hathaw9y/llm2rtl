if {[llength $argv] != 3} {
  error "usage: run_ooc_synthesis.tcl <mm2s_stream_bank_adapter|s2mm_stream_bank_adapter> <evidence_dir> <fresh_work_dir>"
}
set top [lindex $argv 0]
set evidence_dir [file normalize [lindex $argv 1]]
set work_dir [file normalize [lindex $argv 2]]
if {$top ni {mm2s_stream_bank_adapter s2mm_stream_bank_adapter}} {
  error "invalid top: $top"
}
if {[file exists $work_dir]} { error "fresh work directory required: $work_dir" }
file mkdir $evidence_dir
file mkdir $work_dir

set root [file normalize [file join [file dirname [info script]] ".."]]
set rtl_file [file join $root rtl ${top}.sv]
if {![file isfile $rtl_file]} { error "missing RTL: $rtl_file" }

create_project ${top}_ooc [file join $work_dir project] \
    -part xczu7ev-ffvc1156-2-e -force
read_verilog -sv $rtl_file
set_property top $top [current_fileset]
update_compile_order -fileset sources_1
synth_design -top $top -part xczu7ev-ffvc1156-2-e -mode out_of_context
if {[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]] != 0} {
  error "black boxes present"
}

create_clock -name aclk -period 5.000 [get_ports aclk]
set clock_sites [get_sites -filter {SITE_TYPE =~ BUFG*}]
if {[llength $clock_sites] == 0} { error "no BUFG-class site for OOC context" }
set clock_site [lindex $clock_sites 0]
set_property HD.CLK_SRC $clock_site [get_ports aclk]
set data_inputs [get_ports -filter {DIRECTION == IN && NAME != aclk}]
set data_outputs [all_outputs]
set_input_delay -clock aclk -max 0.500 $data_inputs
set_input_delay -clock aclk -min 0.000 $data_inputs
set_output_delay -clock aclk -max 0.500 $data_outputs
set_output_delay -clock aclk -min 0.000 $data_outputs
set_false_path -hold -from $data_inputs
set_false_path -hold -to $data_outputs

set prefix [file join $evidence_dir $top]
write_checkpoint -force ${prefix}_post_synth.dcp
report_utilization -hierarchical -file ${prefix}_utilization_post_synth.rpt
report_timing_summary -delay_type min_max -check_timing_verbose \
    -max_paths 20 -file ${prefix}_timing_post_synth.rpt
report_drc -file ${prefix}_drc_post_synth.rpt
report_methodology -file ${prefix}_methodology_post_synth.rpt
set setup_paths [get_timing_paths -delay_type max -max_paths 1]
set hold_paths [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup_paths] == 0} { error "no setup timing path" }
if {[llength $hold_paths] == 0} { error "no hold timing path" }
puts "TOP=$top"
puts "OOC_CLOCK_SOURCE=$clock_site"
puts "WNS=[get_property SLACK [lindex $setup_paths 0]]"
puts "WHS=[get_property SLACK [lindex $hold_paths 0]]"
puts "PASS: $top Vivado 2025.2 OOC synthesis 5.000ns"
exit
