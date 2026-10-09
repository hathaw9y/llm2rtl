if {[llength $argv]!=1} {error "usage: control_ooc.tcl <source/report directory>"}
set out [file normalize [lindex $argv 0]]
source [file join $out sources.tcl]
synth_design -top control_ooc_shell -part xczu7ev-ffvc1156-2-e -mode out_of_context
if {[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]} {error "black boxes remain"}
create_clock -name aclk -period 5.000 [get_ports aclk]
set clock_site [lindex [get_sites -filter {SITE_TYPE =~ BUFG*}] 0]
if {$clock_site eq ""} {error "missing OOC clock buffer context"}
set_property HD.CLK_SRC $clock_site [get_ports aclk]
puts "OOC_CLOCK_SOURCE=$clock_site"
set inputs [get_ports -filter {DIRECTION == IN && NAME != aclk}]
set outputs [all_outputs]
set_input_delay -clock aclk -max 0.500 $inputs
set_input_delay -clock aclk -min 0.000 $inputs
set_output_delay -clock aclk -max 0.500 $outputs
set_output_delay -clock aclk -min 0.000 $outputs
# Exclude external boundary hold only; internal estimated paths remain timed.
# Physical external-I/O, routing, and board timing require separate signoff.
set_false_path -hold -from $inputs
set_false_path -hold -to $outputs
report_timing_summary -delay_type min_max -check_timing_verbose -file [file join $out timing_summary.rpt]
report_utilization -hierarchical -file [file join $out utilization.rpt]
report_ram_utilization -file [file join $out ram_utilization.rpt]
report_drc -file [file join $out drc.rpt]
report_methodology -file [file join $out methodology.rpt]
write_checkpoint [file join $out control_ooc.dcp]
if {[llength [get_timing_paths -delay_type max -max_paths 1]]==0} {error "no constrained setup path"}
puts ATTENTION_CONTROL_OOC_PASS
exit
