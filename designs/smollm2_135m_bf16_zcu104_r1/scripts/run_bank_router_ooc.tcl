set design_dir [file normalize [file join [file dirname [info script]] ..]]
set rtl_file [file join $design_dir rtl smollm2_bank_port_router.sv]
set xdc_file [file join $design_dir scripts bank_router_clock.xdc]
set out_dir [file join $design_dir evidence smollm2_bank_port_router run_003]
file mkdir $out_dir

create_project -in_memory -part xczu7ev-ffvc1156-2-e
add_files $rtl_file
set_property file_type SystemVerilog [get_files $rtl_file]
add_files -fileset constrs_1 $xdc_file
synth_design -mode out_of_context -top smollm2_bank_port_router -part xczu7ev-ffvc1156-2-e
report_utilization -file [file join $out_dir utilization_post_synth.rpt]
report_timing_summary -file [file join $out_dir timing_post_synth.rpt]
report_drc -file [file join $out_dir drc_post_synth.rpt]
write_checkpoint -force [file join $out_dir smollm2_bank_port_router_synth.dcp]
