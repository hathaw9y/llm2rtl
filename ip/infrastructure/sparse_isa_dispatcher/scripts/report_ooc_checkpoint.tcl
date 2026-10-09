if {[llength $argv] != 2} {error "usage: report_ooc_checkpoint.tcl <dcp> <report>"}
set dcp [file normalize [lindex $argv 0]]
set report [file normalize [lindex $argv 1]]
if {![file isfile $dcp]} {error "missing checkpoint: $dcp"}
open_checkpoint $dcp
report_utilization -file $report
puts "PASS: sparse_isa_dispatcher OOC checkpoint utilization extraction"
exit
