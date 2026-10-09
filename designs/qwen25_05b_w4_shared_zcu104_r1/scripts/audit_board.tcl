set build [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
set_param general.maxThreads 2
open_checkpoint [file join $build routed.dcp]
report_clocks -file [file join $out clocks.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $out timing_summary.rpt]
report_drc -file [file join $out drc.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
set clocks [get_clocks -of_objects [get_pins -of_objects [get_cells -hier -filter {REF_NAME =~ FD*}] -filter {REF_PIN_NAME == C}]]
if {[llength $clocks]==0} {error "No PL register clocks identified"}
set f [open [file join $out audit_result.txt] w]
foreach clock $clocks {
 set period [get_property PERIOD $clock]
 puts $f "PL_register_clock=$clock period_ns=$period"
 if {abs($period-5.0)>0.000001} {close $f;error "A PL register clock is not200MHz"}
}
set errors [get_drc_violations -quiet -filter {SEVERITY == Error}]
puts $f "DRC_errors=[llength $errors]"
puts $f "physical_FPGA_execution=not_performed"
close $f
if {[llength $errors]!=0} {error "Board DRC errors remain"}
puts "PASS_BOARD_CLOCK_AND_DRC_AUDIT_PENDING_REPORT_CHECK"
