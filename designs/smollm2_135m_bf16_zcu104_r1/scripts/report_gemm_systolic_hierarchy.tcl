set design_dir [file normalize [file join [file dirname [info script]] ..]]
set out_dir [file join $design_dir evidence smollm2_gemm_systolic_executor run_006]
open_checkpoint [file join $out_dir smollm2_gemm_systolic_executor_synth.dcp]
report_utilization -hierarchical -file [file join $out_dir utilization_hierarchical_post_synth.rpt]
