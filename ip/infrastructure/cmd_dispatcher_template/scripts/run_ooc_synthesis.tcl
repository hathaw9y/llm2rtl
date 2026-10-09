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

# Capture the same generated native source closure used by the connected tests.
# The OOC top is the controller boundary; the memories are outside that top and
# these reports do not establish payload routing or board memory utilization.
set repo_root [file normalize [file join $template_dir ../../..]]
set bank_template_dir [file join $repo_root ip/infrastructure/bank_subsystem_template/rtl]
set generated_sources {}
foreach filename {bank_config_pkg.sv bank_subsystem.sv} {
    set input_path [file join $bank_template_dir "$filename.tpl"]
    set stream [open $input_path r]
    set data [read $stream]
    close $stream
    set data [string map [list "{{PACKAGE_NAME}}" controller_test_config_pkg "{{MODULE_NAME}}" controller_test_bank] $data]
    set output_path [file join $work_dir $filename]
    set stream [open $output_path w]
    puts -nonewline $stream $data
    close $stream
    lappend generated_sources $output_path
}
set native_sources [list [lindex $generated_sources 0]]
foreach name {bank_native_ownership bank_native_router bank_native_memories} {
    lappend native_sources [file join $repo_root ip/infrastructure/bank_subsystem/rtl "$name.sv"]
}
foreach name {bram_bank uram_bank} {
    lappend native_sources [file join $repo_root ip/infrastructure/datamover_engine/rtl "$name.sv"]
}
lappend native_sources [lindex $generated_sources 1]
set identity_sources [concat $native_sources [list $rtl_file [file join $template_dir template_contract.json] [file join $template_dir template_index.json] [file join $repo_root ip/infrastructure/bank_subsystem/contracts/native_v3.json] [file join $repo_root contracts/common/engine_completion_contract.json] [info script]]]
set sha_stream [open [file join $evidence_dir source_manifest.sha256] w]
foreach input_path $identity_sources {
    if {![file isfile $input_path]} {error "missing source $input_path"}
    puts $sha_stream [exec sha256sum $input_path]
}
close $sha_stream
create_project cmd_dispatcher_template_ooc [file join $work_dir "project"] \
    -part xczu7ev-ffvc1156-2-e -force
foreach input_path $native_sources {read_verilog -sv $input_path}
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
# These exceptions exclude external boundary hold only. Internal estimated
# setup/hold remain timed; physical external-I/O and board timing are unverified.
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
