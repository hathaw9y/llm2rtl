set design [file normalize [lindex $argv 0]]
set evidence [file normalize [lindex $argv 1]]
file mkdir $evidence
foreach name {qwen_fp32_pkg.sv qwen_fp32_pipe.sv qwen_rope_executor.sv} {
  read_verilog -sv [file join $design rtl $name]
}
synth_design -top qwen_rope_executor -part xczu7ev-ffvc1156-2-e -mode out_of_context
create_clock -name pl_clk -period 5 [get_ports clk]
set_input_delay -min 0.300 -clock pl_clk [get_ports -filter {DIRECTION == IN && NAME != clk}]
set_input_delay -max 1.000 -clock pl_clk [get_ports -filter {DIRECTION == IN && NAME != clk}]
set_output_delay 0 -clock pl_clk [get_ports -filter {DIRECTION == OUT}]
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $evidence timing_summary.rpt]
report_utilization -file [file join $evidence utilization.rpt]
report_drc -file [file join $evidence drc.rpt]
write_checkpoint -force [file join $evidence routed.dcp]
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
set f [open [file join $evidence result.txt] w]
puts $f "scope=RoPE_module_only\nclock_MHz=200\ninput_delay_min_ns=0.300\ninput_delay_max_ns=1.000\nsetup_slack_ns=$wns\nhold_slack_ns=$whs"
close $f
if {$wns < 0 || $whs < 0} {error "RoPE module timing failed; no board timing claim"}
