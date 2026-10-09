set_param general.maxThreads 4
set design_dir [file normalize [file join [file dirname [info script]] ..]]
set repo_dir [file normalize [file join $design_dir .. ..]]
create_project -in_memory -part xczu7ev-ffvc1156-2-e
set_property target_language Verilog [current_project]
set_property XPM_LIBRARIES {XPM_MEMORY} [current_project]
read_verilog -sv [file join $repo_dir ip infrastructure datamover_engine rtl bram_bank.sv]
read_verilog -sv [file join $design_dir rtl smollm2_command_bram.sv]
set f [open clock.xdc w]
puts $f {create_clock -name core_clk -period 5.000 [get_ports clk]}
close $f
read_xdc clock.xdc
synth_design -top smollm2_command_bram -part xczu7ev-ffvc1156-2-e -mode out_of_context
report_utilization -file utilization.rpt
report_utilization -hierarchical -file utilization_hier.rpt
report_timing_summary -delay_type min_max -check_timing_verbose -max_paths 10 -file timing_summary.rpt
report_timing -delay_type max -max_paths 20 -file setup_paths.rpt
report_timing -delay_type min -max_paths 10 -file hold_paths.rpt
report_drc -file drc.rpt
report_methodology -file methodology.rpt
write_checkpoint -force command_bram.dcp
puts "OOC_COMPLETE_EXECUTED command_bram top=smollm2_command_bram part=xczu7ev-ffvc1156-2-e clock_ns=5.000"
exit
