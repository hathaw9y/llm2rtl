# Preparation only. User must designate build machine before execution.
if {![string match "2025.2*" [version -short]]} {error "Exact Vivado2025.2 required"}
if {[llength $argv]!=1} {error "Usage: vivado -mode batch -source ooc.tcl -tclargs TOP"}
set top [lindex $argv 0]
if {$top ni {w8a8_fp32_div4 w8a8_quant_lane4 w8a8_dequant_lane4}} {error "Unsupported top"}
set evidence [file normalize [file dirname [info script]]]
set design [file normalize [file join $evidence ../..]]
set run [file join $evidence ooc_$top]
file mkdir $run
cd $run
foreach name {w8a8_fp32_pkg.sv w8a8_fp32_mul.sv w8a8_fp32_div4.sv w8a8_quant_lane4.sv w8a8_dequant_lane4.sv} {
 read_verilog -sv [file join $design rtl $name]
}
synth_design -top $top -part xczu7ev-ffvc1156-2-e -mode out_of_context
create_clock -name clk -period 5.000 [get_ports clk]
report_utilization -file utilization_synth.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file timing_synth.rpt
report_drc -file drc_synth.rpt
report_methodology -file methodology_synth.rpt
write_checkpoint -force synthesized.dcp
