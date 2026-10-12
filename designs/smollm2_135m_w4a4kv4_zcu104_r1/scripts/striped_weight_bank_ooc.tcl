if {[llength $argv] != 3} { error "usage: striped_weight_bank_ooc.tcl <leaf> <uram> <reports>" }
set leaf [file normalize [lindex $argv 0]]
set uram [file normalize [lindex $argv 1]]
set reports [file normalize [lindex $argv 2]]
file mkdir $reports
set part xczu7ev-ffvc1156-2-e
create_project striped_weight_bank_ooc ./project -part $part -force
set_property XPM_LIBRARIES {XPM_MEMORY} [current_project]
read_verilog -sv [list $uram $leaf]
set_property top smollm2_striped_weight_bank [current_fileset]
update_compile_order -fileset sources_1
synth_design -top smollm2_striped_weight_bank -part $part -mode out_of_context
create_clock -name aclk -period 5.000 [get_ports aclk]
set clock_site [lindex [get_sites -filter {SITE_TYPE =~ BUFG*}] 0]
set_property HD.CLK_SRC $clock_site [get_ports aclk]
set inputs [get_ports -filter {DIRECTION == IN && NAME != aclk}]
set_input_delay -clock aclk -max 0.500 $inputs
set_input_delay -clock aclk -min 0.000 $inputs
set_output_delay -clock aclk -max 0.500 [all_outputs]
set_output_delay -clock aclk -min 0.000 [all_outputs]
# No false paths: preserve any failing post-synthesis endpoint in the reports.
set urams [get_cells -hier -filter {REF_NAME =~ URAM288*}]
set brams [get_cells -hier -filter {REF_NAME =~ RAMB*}]
set blackboxes [get_cells -hier -filter {IS_BLACKBOX == 1}]
set mapping [open [file join $reports mapping.txt] w]
puts $mapping "top=smollm2_striped_weight_bank"
puts $mapping "part=$part"
puts $mapping "stage=post_synthesis"
puts $mapping "clock_period_ns=5.000"
puts $mapping "clock_source=$clock_site"
puts $mapping "uram288_count=[llength $urams]"
puts $mapping "ramb_count=[llength $brams]"
puts $mapping "blackbox_count=[llength $blackboxes]"
foreach u $urams { puts $mapping "uram_cell=[get_property NAME $u]" }
set maxpaths [get_timing_paths -delay_type max -max_paths 1]
set minpaths [get_timing_paths -delay_type min -max_paths 1]
puts $mapping "setup_paths=[llength $maxpaths]"
puts $mapping "hold_paths=[llength $minpaths]"
if {[llength $maxpaths]} { puts $mapping "worst_setup_slack_ns=[get_property SLACK [lindex $maxpaths 0]]" }
if {[llength $minpaths]} { puts $mapping "worst_hold_slack_ns=[get_property SLACK [lindex $minpaths 0]]" }
close $mapping
write_checkpoint -force [file join $reports post_synth.dcp]
report_utilization -hierarchical -file [file join $reports utilization_hierarchical.rpt]
report_utilization -file [file join $reports utilization.rpt]
report_timing_summary -delay_type min_max -check_timing_verbose -file [file join $reports timing_summary.rpt]
report_timing -delay_type max -max_paths 10 -file [file join $reports setup_paths.rpt]
report_timing -delay_type min -max_paths 10 -file [file join $reports hold_paths.rpt]
report_clocks -file [file join $reports clocks.rpt]
report_drc -file [file join $reports drc.rpt]
report_methodology -file [file join $reports methodology.rpt]
report_exceptions -file [file join $reports exceptions.rpt]
if {[llength $blackboxes] != 0 || [llength $urams] == 0} { error "memory mapping gate failed" }
puts "PASS: smollm2 striped bank default-depth OOC mapping"
exit
