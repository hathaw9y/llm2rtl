set_param general.maxThreads 4
set design /home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1
read_verilog -sv [list $design/rtl/bank_ownership_table.sv $design/rtl/smollm2_bank_controller.sv]
synth_design -top smollm2_bank_controller -part xczu7ev-ffvc1156-2-e -mode out_of_context
create_clock -name clk -period 5.000 [get_ports clk]
report_clocks -file clocks.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file timing_summary.rpt
report_timing -delay_type max -max_paths 10 -file setup_paths.rpt
report_timing -delay_type min -max_paths 10 -file hold_paths.rpt
report_utilization -hierarchical -file utilization_hierarchical.rpt
report_utilization -file utilization.rpt
report_drc -file drc.rpt
report_methodology -file methodology.rpt
write_checkpoint -force bank_controller.dcp
puts "PASS_BANK_CONTROLLER_OOC_SYNTH_EXECUTED"
