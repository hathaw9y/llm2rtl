set design_dir [file normalize [file join [file dirname [info script]] ..]]
set project_dir [file join $design_dir build zcu104_dma_rms_gemm_rope_attention_add_board_probe_100mhz]
open_project [file join $project_dir zcu104_dma_rms_gemm_rope_attention_add_board_probe_100mhz.xpr]
reset_run impl_1
reset_run synth_1
reset_run system_probe_0_synth_1
puts "DMA_BOARD_RUNS_RESET $project_dir"
