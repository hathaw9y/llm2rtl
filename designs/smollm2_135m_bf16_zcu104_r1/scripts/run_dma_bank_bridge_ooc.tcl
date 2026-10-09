set design_dir [file normalize [file join [file dirname [info script]] ..]]
set repo_dir [file normalize [file join $design_dir ../..]]
set out_dir [file join $design_dir evidence smollm2_dma_bank_bridge run_007]
file mkdir $out_dir

create_project -in_memory -part xczu7ev-ffvc1156-2-e
foreach name [list pipeline fifo axis_width_up_converter axis_width_down_converter \
                   axis_width_converter mm2s_adapter s2mm_adapter] {
    set source [file join $repo_dir ip infrastructure datamover_engine rtl ${name}.sv]
    add_files $source
    set_property file_type SystemVerilog [get_files $source]
}
set bridge [file join $design_dir rtl smollm2_dma_bank_bridge.sv]
add_files $bridge
set_property file_type SystemVerilog [get_files $bridge]
add_files -fileset constrs_1 [file join $design_dir scripts bank_memories_clock.xdc]
synth_design -mode out_of_context -top smollm2_dma_bank_bridge -part xczu7ev-ffvc1156-2-e
report_utilization -file [file join $out_dir utilization_post_synth.rpt]
report_timing_summary -file [file join $out_dir timing_post_synth.rpt]
report_drc -file [file join $out_dir drc_post_synth.rpt]
write_checkpoint -force [file join $out_dir smollm2_dma_bank_bridge_synth.dcp]
