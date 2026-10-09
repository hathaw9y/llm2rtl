set script_dir [file dirname [file normalize [info script]]]
set design_dir [file normalize [file join $script_dir ".."]]
set rtl_file [file join $design_dir "rtl" "isa_command_dispatcher.sv"]
set evidence_dir [file join $design_dir "evidence" "isa_command_dispatcher"]
set work_dir [file join $evidence_dir "vivado_ooc_work"]
file mkdir $evidence_dir
file delete -force $work_dir
file mkdir $work_dir
create_project dispatcher_r3_ooc [file join $work_dir "project"] -part xczu7ev-ffvc1156-2-e -force
read_verilog -sv $rtl_file
set_property top isa_command_dispatcher [current_fileset]
update_compile_order -fileset sources_1
synth_design -top isa_command_dispatcher -part xczu7ev-ffvc1156-2-e -mode out_of_context
create_clock -name aclk -period 5.000 [get_ports aclk]
set clock_buffer_sites [get_sites -filter {SITE_TYPE =~ BUFG*}]
if {[llength $clock_buffer_sites] == 0} {error "No BUFG-class clock source site"}
set ooc_clock_source [lindex $clock_buffer_sites 0]
set_property HD.CLK_SRC $ooc_clock_source [get_ports aclk]
puts "OOC clock context source: $ooc_clock_source"
set data_inputs [get_ports -filter {DIRECTION == IN && NAME != aclk}]
set_input_delay -clock aclk -max 0.500 $data_inputs
set_input_delay -clock aclk -min 0.000 $data_inputs
set_output_delay -clock aclk -max 0.500 [all_outputs]
set_output_delay -clock aclk -min 0.000 [all_outputs]
set_false_path -hold -from $data_inputs
set_false_path -hold -to [all_outputs]
write_checkpoint -force [file join $evidence_dir "isa_command_dispatcher_post_synth.dcp"]
report_utilization -file [file join $evidence_dir "utilization_post_synth.rpt"]
report_drc -file [file join $evidence_dir "drc_post_synth.rpt"]
report_methodology -file [file join $evidence_dir "methodology_post_synth.rpt"]
report_timing_summary -delay_type min_max -check_timing_verbose -file [file join $evidence_dir "timing_post_synth.rpt"]
if {[llength [get_timing_paths -delay_type max -max_paths 1]] == 0} {error "No setup timing path"}
puts "DISPATCHER_R3_OOC_SYNTH_PASS"
exit
