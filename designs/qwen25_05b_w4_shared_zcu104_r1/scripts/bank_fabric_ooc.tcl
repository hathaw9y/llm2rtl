set design [file normalize [lindex $argv 0]]
set evidence [file normalize [lindex $argv 1]]
file mkdir $evidence
set root [file normalize [file join $design ../..]]
foreach f {bram_bank.sv uram_bank.sv} {read_verilog -sv [file join $root ip infrastructure datamover_engine rtl $f]}
read_verilog -sv [file join $design rtl qwen_bank_fabric.sv]
synth_design -top qwen_bank_fabric -part xczu7ev-ffvc1156-2-e -mode out_of_context
create_clock -name pl_clk -period 5 [get_ports clk]
set_input_delay -min 0.300 -clock pl_clk [get_ports -filter {DIRECTION == IN && NAME != clk}]
set_input_delay -max 1.000 -clock pl_clk [get_ports -filter {DIRECTION == IN && NAME != clk}]
set_output_delay 0 -clock pl_clk [get_ports -filter {DIRECTION == OUT}]
opt_design
report_utilization -file [file join $evidence utilization_synth.rpt]
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
puts $f "scope=bank_fabric_module_only\nclock_MHz=200\ninput_delay_min_ns=0.300\ninput_delay_max_ns=1.000\nsetup_slack_ns=$wns\nhold_slack_ns=$whs"
close $f
if {$wns < 0 || $whs < 0} {error "Bank fabric timing failed; no board timing claim"}
