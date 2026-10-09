if {$argc != 4} { error "usage: <captured-rtl-dir> <output-dir> <top> <dma-width>" }
set rtl [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
set top [lindex $argv 2]
set width [lindex $argv 3]
file mkdir $out
if {$top eq "datamover_engine"} {
  foreach source {datamover_engine_pkg fifo datamover_command_queue mm2s_channel s2mm_channel status_decoder datamover_engine} {
    read_verilog -sv [file join $rtl ${source}.sv]
  }
  synth_design -top $top -part xczu7ev-ffvc1156-2-e -mode out_of_context -generic DMA_DATA_WIDTH=$width
} elseif {$top in {bram_bank uram_bank}} {
  read_verilog -sv [file join $rtl ${top}.sv]
  synth_design -top $top -part xczu7ev-ffvc1156-2-e -mode out_of_context
} else { error "invalid top" }
create_clock -name aclk -period 5.000 [get_ports aclk]
set clk_site [lindex [get_sites -quiet -filter {SITE_TYPE =~ BUFG*}] 0]
if {$clk_site eq ""} { error "no BUFG site" }
set_property HD.CLK_SRC $clk_site [get_ports aclk]
set data_inputs [get_ports -quiet -filter {DIRECTION == IN && NAME != aclk}]
set_input_delay -clock aclk -max 0.500 $data_inputs
set_input_delay -clock aclk -min 0.000 $data_inputs
set_output_delay -clock aclk -max 0.500 [all_outputs]
set_output_delay -clock aclk -min 0.000 [all_outputs]
# No hold exceptions: retain failures instead of excluding external interfaces.
set blackboxes [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]
set ramb [get_cells -quiet -hier -filter {REF_NAME =~ RAMB*}]
set uram [get_cells -quiet -hier -filter {REF_NAME =~ URAM288*}]
set meta [open [file join $out mapping.txt] w]
puts $meta "top=$top\npart=xczu7ev-ffvc1156-2-e\nclock_period_ns=5.000\nblackboxes=[llength $blackboxes]\nramb=[llength $ramb]\nuram=[llength $uram]"
close $meta
if {[llength $blackboxes] != 0} { error "unexpected blackboxes" }
if {$top eq "bram_bank" && ([llength $ramb] == 0 || [llength $uram] != 0)} { error "BRAM mapping failed" }
if {$top eq "uram_bank" && [llength $uram] == 0} { error "URAM mapping failed" }
report_timing_summary -delay_type min_max -check_timing_verbose -max_paths 10 -file [file join $out timing_summary.rpt]
report_timing -delay_type max -max_paths 10 -file [file join $out timing_paths.rpt]
report_utilization -hierarchical -file [file join $out utilization.rpt]
report_drc -file [file join $out drc.rpt]
report_methodology -file [file join $out methodology.rpt]
report_exceptions -coverage -file [file join $out exceptions.rpt]
puts "DATAMOVER_CURRENT_SOURCE_OOC_SYNTHESIS_COMPLETE"
exit
