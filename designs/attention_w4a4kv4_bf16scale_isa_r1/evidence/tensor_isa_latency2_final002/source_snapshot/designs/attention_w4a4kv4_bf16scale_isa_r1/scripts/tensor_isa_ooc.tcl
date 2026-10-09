set out [file normalize [lindex $argv 0]]
set cmd_latency [lindex $argv 1]
source [file join $out sources.tcl]
synth_design -top attention_tensor_isa_top -part xczu7ev-ffvc1156-2-e -mode out_of_context -generic [list CMD_ADDR_WIDTH=6 MAX_COMMANDS=64 CMD_READ_LATENCY=$cmd_latency]
if {[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]} {error "black boxes"}
create_clock -name aclk -period 5.000 [get_ports aclk]
set_property HD.CLK_SRC [lindex [get_sites -filter {SITE_TYPE =~ BUFG*}] 0] [get_ports aclk]
set inputs [get_ports -filter {DIRECTION == IN && NAME != aclk}]
set_input_delay -clock aclk -max 0.500 $inputs
set_input_delay -clock aclk -min 0.000 $inputs
set_output_delay -clock aclk -max 0.500 [all_outputs]
set_output_delay -clock aclk -min 0.000 [all_outputs]
# Unplaced OOC: external hold is excluded; internal hold remains timed.
set_false_path -hold -from $inputs
set_false_path -hold -to [all_outputs]
report_timing_summary -delay_type min_max -check_timing_verbose -file [file join $out timing_summary.rpt]
report_utilization -hierarchical -file [file join $out utilization.rpt]
report_ram_utilization -file [file join $out ram_utilization.rpt]
report_drc -file [file join $out drc.rpt]
report_methodology -file [file join $out methodology.rpt]
write_checkpoint [file join $out tensor_isa.dcp]
if {[llength [get_timing_paths -delay_type max -max_paths 1]]==0} {error "no setup path"}
if {[llength [get_timing_paths -delay_type max -slack_lesser_than 0 -max_paths 1]] || [llength [get_timing_paths -delay_type min -slack_lesser_than 0 -max_paths 1]]} {error "negative timing slack"}
puts ATTENTION_TENSOR_ISA_OOC_PASS
exit
