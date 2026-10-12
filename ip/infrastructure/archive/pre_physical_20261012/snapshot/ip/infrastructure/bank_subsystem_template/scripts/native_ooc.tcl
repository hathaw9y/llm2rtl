set out_dir [file normalize [lindex $argv 0]]
source [file join $out_dir sources.tcl]
synth_design -top native_test_bank_subsystem -part xczu7ev-ffvc1156-2-e -mode out_of_context
create_clock -name aclk -period 5.000 [get_ports aclk]
report_timing_summary -delay_type min_max -max_paths 20 -file [file join $out_dir timing_summary.rpt]
report_utilization -hierarchical -file [file join $out_dir utilization.rpt]
report_drc -file [file join $out_dir drc.rpt]
report_methodology -file [file join $out_dir methodology.rpt]
report_ram_utilization -file [file join $out_dir ram_utilization.rpt]
write_checkpoint [file join $out_dir native_bank_ooc.dcp]
puts NATIVE_BANK_OOC_PASS
exit
