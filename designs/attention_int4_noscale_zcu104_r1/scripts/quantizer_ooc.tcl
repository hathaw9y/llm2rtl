if {[llength $argv] != 2} {error "usage: quantizer_ooc.tcl <exact RTL> <fresh report directory>"}
set rtl [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
read_verilog -sv $rtl
synth_design -top attention_int4_quantizer -part xczu7ev-ffvc1156-2-e -mode out_of_context
if {[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]} {error "black boxes remain"}
create_clock -name aclk -period 5.000 [get_ports aclk]
set clock_site [lindex [get_sites -filter {SITE_TYPE =~ BUFG*}] 0]
if {$clock_site eq ""} {error "missing OOC clock buffer context"}
set_property HD.CLK_SRC $clock_site [get_ports aclk]
puts "OOC_CLOCK_SOURCE=$clock_site"
set inputs [get_ports -filter {DIRECTION == IN && NAME != aclk}]
set outputs [all_outputs]
set_input_delay -clock aclk -max 0.500 $inputs
set_input_delay -clock aclk -min 0.000 $inputs
set_output_delay -clock aclk -max 0.500 $outputs
set_output_delay -clock aclk -min 0.000 $outputs
# External boundary hold is excluded; internal estimated paths remain timed.
# These estimates provide neither physical external-I/O nor board signoff.
set_false_path -hold -from $inputs
set_false_path -hold -to $outputs
report_timing_summary -delay_type min_max -check_timing_verbose -file [file join $out timing_summary.rpt]
report_utilization -hierarchical -file [file join $out utilization.rpt]
report_ram_utilization -file [file join $out ram_utilization.rpt]
report_drc -file [file join $out drc.rpt]
report_methodology -file [file join $out methodology.rpt]
write_checkpoint [file join $out quantizer_ooc.dcp]
if {[llength [get_timing_paths -delay_type max -max_paths 1]]==0} {error "no constrained setup path"}
puts ATTENTION_INT4_QUANTIZER_OOC_PASS
exit
