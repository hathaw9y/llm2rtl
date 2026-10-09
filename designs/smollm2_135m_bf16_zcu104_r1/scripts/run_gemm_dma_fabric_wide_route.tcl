set design_dir [file normalize [file join [file dirname [info script]] ..]]
set repo_dir [file normalize [file join $design_dir ../..]]
set out_dir [file join $design_dir evidence smollm2_gemm_dma_fabric_wide run_001]
file mkdir $out_dir
create_project -in_memory -part xczu7ev-ffvc1156-2-e

foreach name [list datamover_engine_pkg fifo pipeline axis_width_up_converter \
                   axis_width_down_converter axis_width_converter mm2s_adapter \
                   s2mm_adapter datamover_command_queue mm2s_channel \
                   s2mm_channel datamover_engine bram_bank uram_bank] {
    set source [file join $repo_dir ip infrastructure datamover_engine rtl ${name}.sv]
    add_files $source
    set_property file_type SystemVerilog [get_files $source]
}
set source [file join $repo_dir ip infrastructure bank_ownership_table rtl bank_ownership_table.sv]
add_files $source
set_property file_type SystemVerilog [get_files $source]
foreach name [list smollm2_bank_port_router_wide smollm2_bank_memories_wide \
                   smollm2_bank_subsystem_wide smollm2_dma_bank_bridge \
                   smollm2_dma_engine_link bank_tensor_state_tracker \
                   isa_command_dispatcher smollm2_dma_control_fabric_wide \
                   smollm2_gemm_systolic_wide_executor \
                   smollm2_gemm_dma_fabric_wide] {
    set source [file join $design_dir rtl ${name}.sv]
    add_files $source
    set_property file_type SystemVerilog [get_files $source]
}
add_files -fileset constrs_1 [file join $design_dir scripts bank_memories_clock.xdc]
synth_design -mode out_of_context -flatten_hierarchy none \
    -top smollm2_gemm_dma_fabric_wide -part xczu7ev-ffvc1156-2-e
report_utilization -file [file join $out_dir utilization_post_synth.rpt]
report_timing_summary -file [file join $out_dir timing_post_synth.rpt]
write_checkpoint -force [file join $out_dir synthesized.dcp]
opt_design
place_design
report_utilization -file [file join $out_dir utilization_post_place.rpt]
report_timing_summary -file [file join $out_dir timing_post_place.rpt]
write_checkpoint -force [file join $out_dir placed.dcp]
phys_opt_design
route_design
report_utilization -file [file join $out_dir utilization_post_route.rpt]
report_timing_summary -file [file join $out_dir timing_post_route.rpt]
report_drc -file [file join $out_dir drc_post_route.rpt]
write_checkpoint -force [file join $out_dir routed.dcp]
