set target [lindex $argv 0]
set output [file normalize [lindex $argv 1]]
set source_dir [file normalize [lindex $argv 2]]
read_verilog -sv [glob $source_dir/attention_fp32_*.sv] $source_dir/attention_exp_neg.sv
synth_design -top $target -part xczu7ev-ffvc1156-2-e -mode out_of_context
create_clock -name aclk -period 5.000 [get_ports aclk]
set sites [get_sites -filter {SITE_TYPE =~ BUFG*}]
set_property HD.CLK_SRC [lindex $sites 0] [get_ports aclk]
set inputs [get_ports -filter {DIRECTION == IN && NAME != aclk}]
set outputs [get_ports -filter {DIRECTION == OUT}]
set_input_delay -clock aclk -max 0.500 $inputs
set_input_delay -clock aclk -min 0.000 $inputs
set_output_delay -clock aclk -max 0.500 $outputs
set_output_delay -clock aclk -min 0.000 $outputs
set_false_path -hold -from $inputs
set_false_path -hold -to $outputs
if {[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]!=0} {error blackbox}
report_utilization -file $output/utilization.rpt
report_timing_summary -delay_type min_max -file $output/timing_summary.rpt
report_drc -file $output/drc.rpt
report_methodology -file $output/methodology.rpt
write_checkpoint -force $output/math_ooc.dcp
puts ATTENTION_MATH_OOC_PASS
