if {[llength $argv] != 4} {
  error "usage: run_memory_bank_ooc.tcl <bram_bank|uram_bank> <rtl_file> <evidence_dir> <work_dir>"
}
set top [lindex $argv 0]
set rtl_file [file normalize [lindex $argv 1]]
set evidence_dir [file normalize [lindex $argv 2]]
set work_dir [file normalize [lindex $argv 3]]
if {$top ni {bram_bank uram_bank}} { error "invalid top: $top" }
if {[file exists $work_dir]} { error "fresh work directory required: $work_dir" }
file mkdir $work_dir
file mkdir $evidence_dir
create_project ${top}_ooc [file join $work_dir project] -part xczu7ev-ffvc1156-2-e -force
read_verilog -sv $rtl_file
set_property top $top [current_fileset]
update_compile_order -fileset sources_1
synth_design -top $top -part xczu7ev-ffvc1156-2-e -mode out_of_context
create_clock -name aclk -period 5.000 [get_ports aclk]
set clock_site [lindex [get_sites -filter {SITE_TYPE =~ BUFG*}] 0]
set_property HD.CLK_SRC $clock_site [get_ports aclk]
set data_inputs [get_ports -filter {DIRECTION == IN && NAME != aclk}]
set_input_delay -clock aclk -max 0.5 $data_inputs
set_input_delay -clock aclk -min 0.0 $data_inputs
set_output_delay -clock aclk -max 0.5 [all_outputs]
set_output_delay -clock aclk -min 0.0 [all_outputs]
set_false_path -hold -from $data_inputs
set_false_path -hold -to [all_outputs]
set ramb_cells [get_cells -hier -filter {REF_NAME =~ RAMB*}]
set uram_cells [get_cells -hier -filter {REF_NAME =~ URAM288*}]
set blackboxes [get_cells -hier -filter {IS_BLACKBOX == 1}]
set mapping [open [file join $evidence_dir ${top}_mapping.txt] w]
puts $mapping "top=$top"
puts $mapping "ramb_count=[llength $ramb_cells]"
puts $mapping "uram288_count=[llength $uram_cells]"
puts $mapping "blackbox_count=[llength $blackboxes]"
puts $mapping "clock_source=$clock_site"
close $mapping
if {[llength $blackboxes] != 0} { error "black boxes present" }
if {$top eq "bram_bank" && ([llength $ramb_cells] == 0 || [llength $uram_cells] != 0)} {
  error "BRAM mapping gate failed"
}
if {$top eq "uram_bank" && [llength $uram_cells] == 0} {
  error "URAM mapping gate failed"
}
write_checkpoint -force [file join $evidence_dir ${top}_post_synth.dcp]
report_utilization -file [file join $evidence_dir ${top}_utilization.rpt]
report_timing_summary -delay_type min_max -check_timing_verbose \
  -file [file join $evidence_dir ${top}_timing.rpt]
report_drc -file [file join $evidence_dir ${top}_drc.rpt]
puts "PASS: $top Vivado 2025.2 default OOC"
exit
