set design_dir [file normalize [file join [file dirname [info script]] ..]]
set out_dir [file join $design_dir evidence smollm2_attention_executor run_001]
file mkdir $out_dir
create_project -in_memory -part xczu7ev-ffvc1156-2-e
set source [file join $design_dir rtl smollm2_attention_executor.sv]
add_files $source
set_property file_type SystemVerilog [get_files $source]
add_files -fileset constrs_1 [file join $design_dir scripts rope_150mhz.xdc]
foreach mode {0 1} {
    synth_design -mode out_of_context -flatten_hierarchy none \
        -top smollm2_attention_executor -part xczu7ev-ffvc1156-2-e \
        -generic MODE_VALUE=$mode
    report_utilization -file [file join $out_dir utilization_mode${mode}.rpt]
    report_timing_summary -file [file join $out_dir timing_mode${mode}.rpt]
    report_drc -file [file join $out_dir drc_mode${mode}.rpt]
    write_checkpoint -force [file join $out_dir attention_mode${mode}_synth.dcp]
    if {$mode == 0} {close_design}
}
