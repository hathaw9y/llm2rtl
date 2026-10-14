set_param general.maxThreads 4
create_project -in_memory -part xczu7ev-ffvc1156-2-e
read_verilog -sv /home/shmin/llm2rtl/ip/infrastructure/utils/registered_capture.sv
read_verilog -sv /home/shmin/llm2rtl/ip/infrastructure/examples/registered_capture_example.sv
create_clock -name capture_clk -period 5.000 [get_ports aclk]
set_property HD.CLK_SRC BUFGCE_DIV_X0Y16 [get_ports aclk]
set_input_delay -clock capture_clk -min 1.0 [get_ports -filter {DIRECTION == IN && NAME != aclk}]
set_input_delay -clock capture_clk -max 1.0 [get_ports -filter {DIRECTION == IN && NAME != aclk}]
set_output_delay -clock capture_clk -min 1.0 [get_ports -filter {DIRECTION == OUT}]
set_output_delay -clock capture_clk -max 1.0 [get_ports -filter {DIRECTION == OUT}]
synth_design -top registered_capture_example -part xczu7ev-ffvc1156-2-e -mode out_of_context
write_checkpoint -force synthesized.dcp
report_clocks -file clocks.rpt
report_utilization -file utilization.rpt
report_timing_summary -delay_type min_max -check_timing_verbose -report_unconstrained -file timing_summary.rpt
check_timing -verbose -file check_timing.rpt
report_drc -file drc.rpt
report_methodology -file methodology.rpt
if {[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]] != 0} {error "blackbox found"}
set fp [open binding.tsv w]
puts $fp "group\tce_driver\tloads\tce_path_slack\treset_path_slack\tdata_path_slack"
set groups [get_cells -hier -filter {NAME =~ *u_local_ce && REF_NAME == FDRE}]
if {[llength $groups] != 5} {error "expected five protected localCE groups"}
set total 0
foreach cell $groups {
 set q [get_pins -of_objects $cell -filter {REF_PIN_NAME == Q}]
 set net [get_nets -segments -of_objects $q]
 set loads [get_pins -leaf -of_objects $net -filter {DIRECTION == IN}]
 set count [llength $loads]
 if {$count < 1 || $count > 32} {error "invalid CE fanout $count"}
 foreach pin $loads {
  if {[get_property REF_PIN_NAME $pin] ne "CE"} {error "CEQ has nonCE load $pin"}
  set leaf [get_cells -of_objects $pin]
  if {[get_property REF_NAME $leaf] ne "FDRE" || ![string match *u_capture [get_property NAME $leaf]]} {error "CE target is not capture FDRE"}
  set r [get_pins -of_objects $leaf -filter {REF_PIN_NAME == R}]
  set d [get_pins -of_objects $leaf -filter {REF_PIN_NAME == D}]
  set dp [get_timing_paths -to $d -max_paths 1]
  set rp [get_timing_paths -to $r -max_paths 1]
  if {[llength $dp] == 0 || [llength $rp] == 0} {error "empty data/reset path"}
  if {[get_property REF_PIN_NAME [get_pins [get_property STARTPOINT_PIN $dp]]] ne "Q"} {error "data D does not start at prepared Q"}
  report_timing -of_objects $dp -append -file data_paths.rpt
  report_timing -of_objects $rp -append -file reset_paths.rpt
 }
 set cp [get_timing_paths -from $q -to $loads -max_paths 1]
 if {[llength $cp] == 0} {error "empty CEQ to CE path"}
 report_timing -of_objects $cp -append -file ce_paths.rpt
 puts $fp "[get_property NAME $cell]\t[get_property NAME $q]\t$count\t[get_property SLACK $cp]\t[get_property SLACK $rp]\t[get_property SLACK $dp]"
 incr total $count
}
close $fp
if {$total != 136} {error "capture bit count mismatch"}
set fp [open counts.txt w]
puts $fp "local_ce_groups=[llength $groups] capture_bits=$total blackboxes=0"
close $fp
puts "PASS registered_capture OOC bindings"
exit
