set root /home/shmin/llm2rtl
set out /home/shmin/llm2rtl/ip/infrastructure/datamover_engine/evidence/engine/run_001/independent_verification/ooc_retry
file mkdir $out
read_verilog -sv [file join $root ip/infrastructure/datamover_engine/rtl/datamover_engine_pkg.sv]
read_verilog -sv [file join $root ip/infrastructure/datamover_engine/rtl/fifo.sv]
read_verilog -sv [file join $root ip/infrastructure/datamover_engine/rtl/datamover_command_queue.sv]
read_verilog -sv [file join $root ip/infrastructure/datamover_engine/rtl/mm2s_channel.sv]
read_verilog -sv [file join $root ip/infrastructure/datamover_engine/rtl/s2mm_channel.sv]
read_verilog -sv [file join $root ip/infrastructure/datamover_engine/rtl/status_decoder.sv]
read_verilog -sv [file join $root ip/infrastructure/datamover_engine/rtl/datamover_engine.sv]
synth_design -top datamover_engine -part xczu7ev-ffvc1156-2-e -mode out_of_context
create_clock -name aclk -period 5.000 [get_ports aclk]
set clk [get_clocks aclk]
set clk_port [get_ports aclk]
set clk_site [lindex [get_sites -quiet -filter {SITE_TYPE =~ BUFG*}] 0]
if {$clk_site eq ""} { error "no BUFG site" }
set_property HD.CLK_SRC $clk_site $clk_port
set data_inputs [get_ports -quiet -filter {DIRECTION == IN && NAME != aclk}]
set data_outputs [get_ports -quiet -filter {DIRECTION == OUT}]
set_input_delay -clock $clk -max 0.500 $data_inputs
set_input_delay -clock $clk -min 0.000 $data_inputs
set_output_delay -clock $clk -max 0.500 $data_outputs
set_output_delay -clock $clk -min 0.000 $data_outputs
set_false_path -hold -from $data_inputs
set_false_path -hold -to $data_outputs
set blackboxes [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]
puts "INDEPENDENT_BLACKBOX_COUNT [llength $blackboxes]"
if {[llength $blackboxes] != 0} { error "unexpected blackboxes: $blackboxes" }
report_timing_summary -delay_type min_max -max_paths 20 -file [file join $out timing_summary.rpt]
report_utilization -hierarchical -file [file join $out utilization.rpt]
report_drc -file [file join $out drc.rpt]
report_methodology -file [file join $out methodology.rpt]
report_exceptions -coverage -file [file join $out exceptions.rpt]
write_checkpoint -force [file join $out datamover_engine_ooc.dcp]
puts "DATAMOVER_ENGINE_INDEPENDENT_OOC_PASS"
exit
