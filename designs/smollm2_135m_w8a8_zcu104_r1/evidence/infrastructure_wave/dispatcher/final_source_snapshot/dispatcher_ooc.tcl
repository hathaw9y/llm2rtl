set_param general.maxThreads 4
set design_dir [file normalize [file join [file dirname [info script]] ..]]
read_verilog -sv [file join $design_dir rtl smollm2_isa_dispatcher.sv]
set f [open dispatcher_clock.xdc w]
puts $f {create_clock -name clk -period 5.000 [get_ports clk]}
close $f
read_xdc dispatcher_clock.xdc
synth_design -top smollm2_isa_dispatcher -part xczu7ev-ffvc1156-2-e -mode out_of_context
report_utilization -hierarchical -file utilization_synth.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file timing_synth.rpt
report_timing -delay_type max -max_paths 20 -nworst 1 -file top_setup_paths.rpt
report_clocks -file clocks_synth.rpt
report_drc -file drc_synth.rpt
report_methodology -file methodology_synth.rpt
write_checkpoint -force dispatcher_synth.dcp
puts DISPATCHER_OOC_SYNTH_COMPLETE
exit
