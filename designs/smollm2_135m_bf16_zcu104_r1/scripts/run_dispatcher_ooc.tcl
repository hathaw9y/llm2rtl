set design_dir [file normalize [file join [file dirname [info script]] ..]]
set rtl_file [file join $design_dir rtl isa_command_dispatcher.sv]
set xdc_file [file join $design_dir scripts dispatcher_clock.xdc]
set out_dir [file join $design_dir evidence isa_command_dispatcher run_004]
file mkdir $out_dir

create_project -in_memory -part xczu7ev-ffvc1156-2-e
add_files $rtl_file
set_property file_type SystemVerilog [get_files $rtl_file]
add_files -fileset constrs_1 $xdc_file
synth_design -mode out_of_context -top isa_command_dispatcher -part xczu7ev-ffvc1156-2-e -generic BANK_NUM=13 -generic PORT_ROLE_WIDTH=5
report_utilization -file [file join $out_dir utilization_post_synth.rpt]
report_timing_summary -file [file join $out_dir timing_post_synth.rpt]
report_drc -file [file join $out_dir drc_post_synth.rpt]
write_checkpoint -force [file join $out_dir isa_command_dispatcher_synth.dcp]
