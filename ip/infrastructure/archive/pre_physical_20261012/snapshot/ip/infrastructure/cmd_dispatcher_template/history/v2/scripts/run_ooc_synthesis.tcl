if {[llength $argv] != 2} {
    error "usage: run_ooc_synthesis.tcl <fresh_evidence_dir> <fresh_work_dir>"
}
set evidence_dir [file normalize [lindex $argv 0]]
set work_dir [file normalize [lindex $argv 1]]
if {[file exists $work_dir]} {
    error "fresh work directory required: $work_dir"
}
file mkdir $evidence_dir
file mkdir $work_dir

set script_dir [file dirname [file normalize [info script]]]
set template_dir [file normalize [file join $script_dir ".."]]
set rtl_file [file join $template_dir "rtl" "cmd_dispatcher_template.sv"]
if {![file isfile $rtl_file]} {
    error "missing RTL source: $rtl_file"
}

create_project cmd_dispatcher_template_ooc [file join $work_dir "project"] \
    -part xczu7ev-ffvc1156-2-e -force
read_verilog -sv $rtl_file
set_property top cmd_dispatcher_template [current_fileset]
update_compile_order -fileset sources_1
synth_design -top cmd_dispatcher_template -part xczu7ev-ffvc1156-2-e \
    -mode out_of_context

if {[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]] != 0} {
    error "synthesized design contains black boxes"
}

create_clock -name aclk -period 5.000 [get_ports aclk]
set clock_buffer_sites [get_sites -filter {SITE_TYPE =~ BUFG*}]
if {[llength $clock_buffer_sites] == 0} {
    error "no BUFG-class OOC clock context site"
}
set ooc_clock_source [lindex $clock_buffer_sites 0]
set_property HD.CLK_SRC $ooc_clock_source [get_ports aclk]
puts "OOC_CLOCK_SOURCE=$ooc_clock_source"

set data_inputs [get_ports -filter {DIRECTION == IN && NAME != aclk}]
set data_outputs [all_outputs]
set_input_delay -clock aclk -max 0.500 $data_inputs
set_input_delay -clock aclk -min 0.000 $data_inputs
set_output_delay -clock aclk -max 0.500 $data_outputs
set_output_delay -clock aclk -min 0.000 $data_outputs
set_false_path -hold -from $data_inputs
set_false_path -hold -to $data_outputs

write_checkpoint -force [file join $evidence_dir \
    "cmd_dispatcher_template_post_synth.dcp"]
report_utilization -file [file join $evidence_dir "utilization_post_synth.rpt"]
report_drc -file [file join $evidence_dir "drc_post_synth.rpt"]
report_methodology -file [file join $evidence_dir "methodology_post_synth.rpt"]
report_timing_summary -delay_type min_max -check_timing_verbose \
    -file [file join $evidence_dir "timing_post_synth.rpt"]

if {[llength [get_timing_paths -delay_type max -max_paths 1]] == 0} {
    error "no setup timing path on constrained design"
}
puts "PASS: cmd_dispatcher_template Vivado 2025.2 OOC synthesis"
exit
