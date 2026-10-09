set design_dir [file normalize [file join [file dirname [info script]] ..]]
set repo_dir [file normalize [file join $design_dir ../..]]
set out_dir [file join $design_dir evidence smollm2_bank_subsystem_wide run_001]
file mkdir $out_dir

create_project -in_memory -part xczu7ev-ffvc1156-2-e
foreach source [list \
    [file join $repo_dir ip infrastructure bank_ownership_table rtl bank_ownership_table.sv] \
    [file join $repo_dir ip infrastructure datamover_engine rtl bram_bank.sv] \
    [file join $repo_dir ip infrastructure datamover_engine rtl uram_bank.sv] \
    [file join $design_dir rtl smollm2_bank_port_router_wide.sv] \
    [file join $design_dir rtl smollm2_bank_memories_wide.sv] \
    [file join $design_dir rtl smollm2_bank_subsystem_wide.sv]] {
    add_files $source
    set_property file_type SystemVerilog [get_files $source]
}
add_files -fileset constrs_1 [file join $design_dir scripts bank_memories_clock.xdc]
synth_design -mode out_of_context -top smollm2_bank_subsystem_wide -part xczu7ev-ffvc1156-2-e
report_utilization -file [file join $out_dir utilization_post_synth.rpt]
report_ram_utilization -file [file join $out_dir ram_utilization_post_synth.rpt]
report_timing_summary -file [file join $out_dir timing_post_synth.rpt]
report_drc -file [file join $out_dir drc_post_synth.rpt]
write_checkpoint -force [file join $out_dir smollm2_bank_subsystem_wide_synth.dcp]
