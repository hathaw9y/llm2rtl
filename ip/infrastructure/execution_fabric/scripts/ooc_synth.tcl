set root [file normalize [file join [file dirname [info script]] ../../../..]]
set out [file normalize [lindex $argv 0]]
file mkdir $out
foreach source {
 ip/infrastructure/bank_sparse_router/rtl/bank_config_pkg.sv
 ip/infrastructure/datamover_engine/rtl/datamover_engine_pkg.sv
 ip/infrastructure/datamover_engine/rtl/fifo.sv
 ip/infrastructure/datamover_engine/rtl/datamover_command_queue.sv
 ip/infrastructure/datamover_engine/rtl/mm2s_channel.sv
 ip/infrastructure/datamover_engine/rtl/s2mm_channel.sv
 ip/infrastructure/datamover_engine/rtl/status_decoder.sv
 ip/infrastructure/datamover_engine/rtl/datamover_engine.sv
 ip/infrastructure/stream_bank_adapters/rtl/mm2s_stream_bank_adapter.sv
 ip/infrastructure/stream_bank_adapters/rtl/s2mm_stream_bank_adapter.sv
 ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv
 ip/infrastructure/bank_sparse_router/rtl/bank_sparse_router.sv
 ip/infrastructure/datamover_engine/rtl/bram_bank.sv
 ip/infrastructure/datamover_engine/rtl/uram_bank.sv
 ip/infrastructure/bank_subsystem/rtl/bank_subsystem.sv
 ip/infrastructure/sparse_isa_dispatcher/rtl/sparse_isa_dispatcher.sv
 ip/infrastructure/execution_fabric/rtl/execution_fabric.sv
} {read_verilog -sv [file join $root $source]}
synth_design -top execution_fabric -part xczu7ev-ffvc1156-2-e -mode out_of_context
create_clock -name aclk -period 5.000 [get_ports aclk]
set clk [get_clocks aclk];set clk_port [get_ports aclk]
set clk_site [lindex [get_sites -quiet -filter {SITE_TYPE =~ BUFG*}] 0]
if {$clk_site eq ""} {error "no BUFG site"}
set_property HD.CLK_SRC $clk_site $clk_port
set ins [get_ports -quiet -filter {DIRECTION == IN && NAME != aclk}]
set outs [get_ports -quiet -filter {DIRECTION == OUT}]
set_input_delay -clock $clk -max 0.5 $ins;set_input_delay -clock $clk -min 0.0 $ins
set_output_delay -clock $clk -max 0.5 $outs;set_output_delay -clock $clk -min 0.0 $outs
set_false_path -hold -from $ins;set_false_path -hold -to $outs
set bb [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]
puts "BLACKBOX_COUNT [llength $bb]";if {[llength $bb]} {error "unexpected blackboxes $bb"}
report_timing_summary -delay_type min_max -max_paths 20 -file [file join $out timing_summary.rpt]
report_utilization -hierarchical -file [file join $out utilization.rpt]
report_ram_utilization -file [file join $out ram_utilization.rpt]
report_drc -file [file join $out drc.rpt]
report_methodology -file [file join $out methodology.rpt]
write_checkpoint -force [file join $out execution_fabric_ooc.dcp]
puts "EXECUTION_FABRIC_OOC_COMPLETE"
exit
