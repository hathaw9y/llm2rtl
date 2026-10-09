set root [file normalize [file join [file dirname [info script]] ../../../..]]
if {[llength $argv] != 1} {error "usage: ooc.tcl <fresh_output_dir>"}
set out [file normalize [lindex $argv 0]]
if {[file exists $out]} {error "fresh output directory required: $out"}
file mkdir $out
read_verilog -sv [file join $root ip/infrastructure/bank_sparse_router/rtl/bank_config_pkg.sv]
read_verilog -sv [file join $root ip/infrastructure/sparse_isa_dispatcher/rtl/sparse_isa_dispatcher.sv]
synth_design -top sparse_isa_dispatcher -part xczu7ev-ffvc1156-2-e -mode out_of_context
if {[llength [get_cells -hier -filter {IS_BLACKBOX==1}]] != 0} {error "black boxes present"}
create_clock -name aclk -period 5.000 [get_ports aclk]
set clock_site [lindex [get_sites -filter {SITE_TYPE =~ BUFG*}] 0]
if {$clock_site eq ""} {error "no BUFG-class OOC clock context site"}
set_property HD.CLK_SRC $clock_site [get_ports aclk]
set data_inputs [get_ports -filter {DIRECTION==IN && NAME!=aclk}]
set data_outputs [all_outputs]
set_input_delay -clock aclk -max 0.500 $data_inputs
set_input_delay -clock aclk -min 0.000 $data_inputs
set_output_delay -clock aclk -max 0.500 $data_outputs
set_output_delay -clock aclk -min 0.000 $data_outputs
set_false_path -hold -from $data_inputs
set_false_path -hold -to $data_outputs
report_timing_summary -delay_type min_max -check_timing_verbose -max_paths 20 -file [file join $out timing_summary.rpt]
report_utilization -hierarchical -file [file join $out utilization.rpt]
report_drc -file [file join $out drc.rpt]
report_methodology -file [file join $out methodology.rpt]
write_checkpoint -force [file join $out sparse_isa_dispatcher_ooc.dcp]
set setup_path [get_timing_paths -delay_type max -max_paths 1]
set hold_path [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup_path]==0 || [llength $hold_path]==0} {error "missing setup or hold path"}
puts "OOC_CLOCK_SOURCE=$clock_site"
puts "WNS=[get_property SLACK [lindex $setup_path 0]]"
puts "WHS=[get_property SLACK [lindex $hold_path 0]]"
puts "PASS: sparse_isa_dispatcher Vivado 2025.2 OOC synthesis 5.000ns"
exit
