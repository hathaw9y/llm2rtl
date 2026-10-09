# Run only on user-designated build machine; fresh working directory per run.
set design_dir [file normalize [file join [file dirname [info script]] ..]]
set evidence_dir [file normalize [pwd]]
read_verilog -sv [file join $design_dir rtl int8_dot_core.sv]
synth_design -top int8_dot_core -part xczu7ev-ffvc1156-2-e -mode out_of_context
create_clock -name core_clk -period 5.000 [get_ports clk]
report_utilization -file [file join $evidence_dir utilization_synth.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $evidence_dir timing_synth.rpt]
report_drc -file [file join $evidence_dir drc_synth.rpt]
report_methodology -file [file join $evidence_dir methodology_synth.rpt]
write_checkpoint -force [file join $evidence_dir core_synth.dcp]
set fd [open [file join $evidence_dir primitives.txt] w]
puts $fd "DSP48E2 [llength [get_cells -hier -filter {REF_NAME == DSP48E2}]]"
puts $fd "Blackboxes [llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]"
close $fd
puts CORE_OOC_SYNTH_COMPLETE
exit
