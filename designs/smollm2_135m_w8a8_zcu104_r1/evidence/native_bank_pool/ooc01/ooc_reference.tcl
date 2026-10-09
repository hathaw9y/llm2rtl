set_param general.maxThreads 4
set design /home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1
create_project -in_memory native_bank_pool_ooc -part xczu7ev-ffvc1156-2-e
set_property XPM_LIBRARIES XPM_MEMORY [current_project]
foreach source {bram_bank.sv uram_bank.sv smollm2_bank_payload.sv smollm2_bank_coverage.sv smollm2_native_bank_pool.sv} {
 read_verilog -sv $design/rtl/$source
}
read_xdc $design/scripts/native_bank_pool/clock.xdc
synth_design -top smollm2_native_bank_pool -part xczu7ev-ffvc1156-2-e -mode out_of_context
report_clocks -file clocks.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file timing_summary.rpt
report_timing -delay_type max -max_paths 15 -file setup_paths.rpt
report_timing -delay_type min -max_paths 10 -file hold_paths.rpt
report_utilization -hierarchical -file utilization_hierarchical.rpt
report_utilization -file utilization.rpt
report_drc -file drc.rpt
report_methodology -file methodology.rpt
set boxes [get_cells -hier -filter {IS_BLACKBOX == 1}]
set out [open mapping.tsv w]
puts $out "bank\tpayload_RAM36\tpayload_RAM18\tpayload_URAM\tcoverage_RAM36\tcoverage_RAM18\tcoverage_URAM"
for {set b 0} {$b<16} {incr b} {
 set counts {}
 foreach kind {payload coverage} {
  foreach ref {RAMB36* RAMB18* URAM288*} {
   lappend counts [llength [get_cells -hier -filter "NAME =~ ${kind}_${b}/* && REF_NAME =~ $ref"]]
  }
 }
 puts $out "$b\t[join $counts \t]"
}
puts $out "blackboxes\t[llength $boxes]"
close $out
if {[llength $boxes]!=0} {error "Unresolved blackbox native bank pool"}
write_checkpoint -force native_bank_pool.dcp
puts "PASS_NATIVE_BANK_POOL_OOC_SYNTH_EXECUTED"
