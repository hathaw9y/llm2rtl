# Run in a fresh per-process directory only on the user-designated build machine.
set design_dir [file normalize [file join [file dirname [info script]] ..]]
foreach source {w8a8_fp32_pkg.sv w8a8_fp32_mul.sv w8a8_fp32_div4.sv w8a8_quant_lane4.sv w8a8_dequant_lane4.sv smollm2_quantization_executor.sv} {
 read_verilog -sv [file join $design_dir rtl $source]
}
set clock_file [file join [pwd] quant_executor_clock.xdc]
set fd [open $clock_file w]
puts $fd {create_clock -name executor_clk -period 5.000 [get_ports clk]}
close $fd
read_xdc $clock_file
synth_design -top smollm2_quantization_executor -part xczu7ev-ffvc1156-2-e -mode out_of_context
report_utilization -hierarchical -file utilization_synth.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file timing_synth.rpt
report_drc -file drc_synth.rpt
report_methodology -file methodology_synth.rpt
write_checkpoint -force quant_executor_synth.dcp
puts QUANT_EXECUTOR_OOC_SYNTH_COMPLETE
exit
