set design_dir [file normalize [file join [file dirname [info script]] ..]]
set evidence_dir [file join $design_dir evidence full_output_tap_ooc]
file mkdir $evidence_dir
read_verilog -sv [file join $design_dir rtl smollm2_dma_gemm_board_probe.sv]
synth_design -top smollm2_full_output_tap -part xczu7ev-ffvc1156-2-e -mode out_of_context
report_utilization -file [file join $evidence_dir utilization.rpt]
write_checkpoint -force [file join $evidence_dir synthesized.dcp]
