# Prepared only; execute after build-machine authorization. Exact Vivado2025.2 required.
if {![string match "2025.2*" [version -short]]} { error "Vivado2025.2 required" }
set evidence [file normalize [file dirname [info script]]]
set design [file normalize [file join $evidence ../..]]
set output [file join $evidence ooc_run]
file mkdir $output
cd $output
read_verilog -sv [file join $design rtl w8a8_fp32_pkg.sv]
read_verilog -sv [file join $design rtl w8a8_fp32_mul.sv]
read_verilog -sv [file join $design rtl fp32_bf16_epilogue.sv]
synth_design -top fp32_bf16_epilogue -part xczu7ev-ffvc1156-2-e -mode out_of_context
create_clock -name clk -period 5.000 [get_ports clk]
report_utilization -file utilization_synth.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file timing_synth.rpt
report_drc -file drc_synth.rpt
report_methodology -file methodology_synth.rpt
write_checkpoint -force synthesized.dcp
