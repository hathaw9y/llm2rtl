set design_dir [file normalize [file join [file dirname [info script]] ..]]
set out_dir [file join $design_dir evidence smollm2_gemm_executor run_003]
file mkdir $out_dir
create_project -in_memory -part xczu7ev-ffvc1156-2-e
set source [file join $design_dir rtl smollm2_gemm_executor.sv]
add_files $source
set_property file_type SystemVerilog [get_files $source]
add_files -fileset constrs_1 [file join $design_dir scripts bank_memories_clock.xdc]
synth_design -mode out_of_context -top smollm2_gemm_executor -part xczu7ev-ffvc1156-2-e
report_utilization -file [file join $out_dir utilization_post_synth.rpt]
report_timing_summary -file [file join $out_dir timing_post_synth.rpt]
report_drc -file [file join $out_dir drc_post_synth.rpt]
write_checkpoint -force [file join $out_dir smollm2_gemm_executor_synth.dcp]
