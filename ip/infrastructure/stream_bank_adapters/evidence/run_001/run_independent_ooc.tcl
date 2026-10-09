if {[llength $argv] != 4} {
  error "usage: run_independent_ooc.tcl <top> <rtl_file> <report_dir> <work_dir>"
}
set top [lindex $argv 0]
set rtl_file [file normalize [lindex $argv 1]]
set report_dir [file normalize [lindex $argv 2]]
set work_dir [file normalize [lindex $argv 3]]
if {$top ni {mm2s_stream_bank_adapter s2mm_stream_bank_adapter}} {
  error "unexpected top $top"
}
if {![file isfile $rtl_file]} { error "missing RTL $rtl_file" }
if {[file exists $work_dir]} { error "work_dir must be fresh: $work_dir" }
file mkdir $report_dir
file mkdir $work_dir

create_project independent_${top}_ooc [file join $work_dir project] \
    -part xczu7ev-ffvc1156-2-e -force
read_verilog -sv $rtl_file
set_property top $top [current_fileset]
update_compile_order -fileset sources_1
synth_design -top $top -part xczu7ev-ffvc1156-2-e -mode out_of_context

set blackboxes [get_cells -hier -filter {IS_BLACKBOX == 1}]
if {[llength $blackboxes] != 0} { error "blackboxes=[llength $blackboxes]" }

create_clock -name aclk -period 5.000 [get_ports aclk]
set clk_sites [get_sites -filter {SITE_TYPE =~ BUFG*}]
if {[llength $clk_sites] == 0} { error "no BUFG-class site available" }
set clk_site [lindex $clk_sites 0]
set_property HD.CLK_SRC $clk_site [get_ports aclk]
set data_inputs [get_ports -filter {DIRECTION == IN && NAME != aclk}]
set data_outputs [all_outputs]
set_input_delay -clock aclk -max 0.500 $data_inputs
set_input_delay -clock aclk -min 0.000 $data_inputs
set_output_delay -clock aclk -max 0.500 $data_outputs
set_output_delay -clock aclk -min 0.000 $data_outputs
set_false_path -hold -from $data_inputs
set_false_path -hold -to $data_outputs

set prefix [file join $report_dir $top]
write_checkpoint -force ${prefix}_post_synth.dcp
report_utilization -hierarchical -file ${prefix}_utilization.rpt
report_timing_summary -delay_type min_max -check_timing_verbose \
    -max_paths 20 -file ${prefix}_timing.rpt
report_drc -file ${prefix}_drc.rpt
report_methodology -file ${prefix}_methodology.rpt

set setup_path [get_timing_paths -delay_type max -max_paths 1]
set hold_path [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup_path] != 1} { error "missing setup path" }
if {[llength $hold_path] != 1} { error "missing hold path" }
puts "INDEPENDENT_OOC_TOP=$top"
puts "INDEPENDENT_OOC_PART=xczu7ev-ffvc1156-2-e"
puts "INDEPENDENT_OOC_CLOCK_NS=5.000"
puts "INDEPENDENT_OOC_HD_CLK_SRC=$clk_site"
puts "INDEPENDENT_OOC_BLACKBOXES=[llength $blackboxes]"
puts "INDEPENDENT_OOC_WNS=[get_property SLACK [lindex $setup_path 0]]"
puts "INDEPENDENT_OOC_WHS=[get_property SLACK [lindex $hold_path 0]]"
puts "INDEPENDENT_OOC_PASS $top"
exit
