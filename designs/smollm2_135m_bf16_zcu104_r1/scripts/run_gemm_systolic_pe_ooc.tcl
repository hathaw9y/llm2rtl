set design_dir [file normalize [file join [file dirname [info script]] ..]]
set out_dir [file join $design_dir evidence smollm2_gemm_systolic_executor run_005]
file mkdir $out_dir
create_project -in_memory -part xczu7ev-ffvc1156-2-e
set source [file join $design_dir rtl smollm2_gemm_systolic_executor.sv]
add_files $source
set_property file_type SystemVerilog [get_files $source]
synth_design -mode out_of_context -top smollm2_bf16_systolic_pe -part xczu7ev-ffvc1156-2-e
create_clock -name pe_clk -period 5.000 [get_ports clk]
report_utilization -file [file join $out_dir pe_utilization_post_synth.rpt]
report_timing_summary -file [file join $out_dir pe_timing_post_synth.rpt]
