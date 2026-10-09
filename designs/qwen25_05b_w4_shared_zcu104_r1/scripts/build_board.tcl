set src [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
set stage [lindex $argv 2]
set_param general.maxThreads 2
file mkdir $out
create_project qwen_zcu104 [file join $out project] -part xczu7ev-ffvc1156-2-e -force
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property ip_cache_permissions {read write} [current_project]
read_verilog -sv [file join $src common datamover_engine_pkg.sv]
read_verilog -sv [file join $src rtl qwen_fp32_pkg.sv]
foreach f [glob [file join $src common *.sv]] {if {[file tail $f] ne "datamover_engine_pkg.sv"} {read_verilog -sv $f}}
foreach f [glob [file join $src rtl *.sv]] {if {[file tail $f] ne "qwen_fp32_pkg.sv"} {read_verilog -sv $f}}
foreach f [glob [file join $src rtl *.v]] {read_verilog $f}
create_bd_design qwen_system
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 ps]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} $ps
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {1} CONFIG.PSU__USE__M_AXI_GP1 {0} CONFIG.PSU__USE__S_AXI_GP2 {1} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {RPLL} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {200}] $ps
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 hard_reset
set_property -dict [list CONFIG.C_EXT_RESET_HIGH {0} CONFIG.C_AUX_RESET_HIGH {1}] [get_bd_cells hard_reset]
set_property CONFIG.C_AUX_RESET_HIGH.VALUE_SRC USER [get_bd_cells hard_reset]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 one
set_property CONFIG.CONST_VAL {1} [get_bd_cells one]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 zero
set_property CONFIG.CONST_VAL {0} [get_bd_cells zero]
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 control_bus
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {2}] [get_bd_cells control_bus]
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 ddr_bus
set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {1}] [get_bd_cells ddr_bus]
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 command_controller
set_property -dict [list CONFIG.DATA_WIDTH {32} CONFIG.SINGLE_PORT_BRAM {1} CONFIG.ECC_TYPE {0} CONFIG.READ_LATENCY {2}] [get_bd_cells command_controller]
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_datamover:5.1 mover
set_property -dict [list CONFIG.c_m_axi_mm2s_data_width {128} CONFIG.c_m_axis_mm2s_tdata_width {64} CONFIG.c_m_axi_s2mm_data_width {128} CONFIG.c_s_axis_s2mm_tdata_width {64} CONFIG.c_mm2s_btt_used {23} CONFIG.c_s2mm_btt_used {23} CONFIG.c_mm2s_stscmd_fifo_depth {16} CONFIG.c_s2mm_stscmd_fifo_depth {16}] [get_bd_cells mover]
create_bd_cell -type module -reference qwen_board_ip executor
puts "EXECUTOR_INTERFACES=[get_bd_intf_pins executor/*]"
connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_HPM0_FPD] [get_bd_intf_pins control_bus/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins control_bus/M00_AXI] [get_bd_intf_pins command_controller/S_AXI]
connect_bd_intf_net [get_bd_intf_pins control_bus/M01_AXI] [get_bd_intf_pins executor/S_AXI]
connect_bd_intf_net [get_bd_intf_pins command_controller/BRAM_PORTA] [get_bd_intf_pins executor/CMD_BRAM]
connect_bd_intf_net [get_bd_intf_pins mover/M_AXI_MM2S] [get_bd_intf_pins ddr_bus/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins mover/M_AXI_S2MM] [get_bd_intf_pins ddr_bus/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins ddr_bus/M00_AXI] [get_bd_intf_pins ps/S_AXI_HP0_FPD]
foreach pair {{M_AXIS_MM2S_CMD S_AXIS_MM2S_CMD} {S_AXIS_MM2S M_AXIS_MM2S} {S_AXIS_MM2S_STS M_AXIS_MM2S_STS} {M_AXIS_S2MM_CMD S_AXIS_S2MM_CMD} {M_AXIS_S2MM S_AXIS_S2MM} {S_AXIS_S2MM_STS M_AXIS_S2MM_STS}} {
 connect_bd_intf_net [get_bd_intf_pins executor/[lindex $pair 0]] [get_bd_intf_pins mover/[lindex $pair 1]]
}
set clock [get_bd_pins ps/pl_clk0]
foreach name {hard_reset/slowest_sync_clk control_bus/aclk ddr_bus/aclk command_controller/s_axi_aclk executor/clk ps/maxihpm0_fpd_aclk ps/saxihp0_fpd_aclk} {connect_bd_net $clock [get_bd_pins $name]}
foreach p [get_bd_pins -of_objects [get_bd_cells mover] -filter {TYPE == clk && DIR == I}] {connect_bd_net $clock $p}
connect_bd_net [get_bd_pins ps/pl_resetn0] [get_bd_pins hard_reset/ext_reset_in]
connect_bd_net [get_bd_pins one/dout] [get_bd_pins hard_reset/dcm_locked]
connect_bd_net [get_bd_pins zero/dout] [get_bd_pins hard_reset/aux_reset_in] [get_bd_pins hard_reset/mb_debug_sys_rst]
foreach name {control_bus/aresetn command_controller/s_axi_aresetn executor/rst_n} {connect_bd_net [get_bd_pins hard_reset/peripheral_aresetn] [get_bd_pins $name]}
connect_bd_net [get_bd_pins executor/dma_resetn] [get_bd_pins ddr_bus/aresetn]
foreach p [get_bd_pins mover/*aresetn] {connect_bd_net [get_bd_pins executor/dma_resetn] $p}
assign_bd_address -offset 0xA0000000 -range 32K -target_address_space [get_bd_addr_spaces ps/Data] [get_bd_addr_segs command_controller/S_AXI/Mem0]
assign_bd_address -offset 0xA0010000 -range 64K -target_address_space [get_bd_addr_spaces ps/Data] [get_bd_addr_segs executor/S_AXI/reg0]
assign_bd_address
set validation_failed [catch {validate_bd_design} validation_message]
set clock_file [open [file join $out clock_configuration.txt] w]
puts $clock_file "requested_PL_clock_MHz=200"
puts $clock_file "BD_PL_clock_Hz=[get_property CONFIG.FREQ_HZ [get_bd_pins ps/pl_clk0]]"
foreach property [list_property $ps] {
 if {[regexp {PL0_REF_CTRL|IOPLL_CTRL|RPLL_CTRL|APLL_CTRL} $property]} {puts $clock_file "$property=[get_property $property $ps]"}
}
close $clock_file
if {$validation_failed} {error $validation_message}
# External polarity propagates from the PS resetn pin during validation.
# Low auxiliary/debug constants must be inactive, while PS resetn is active-low.
if {[get_property CONFIG.C_EXT_RESET_HIGH [get_bd_cells hard_reset]]!=0 || [get_property CONFIG.C_AUX_RESET_HIGH [get_bd_cells hard_reset]]!=1} {error "Wrong hard reset polarity after BD propagation"}
if {[get_property CONFIG.FREQ_HZ [get_bd_pins ps/pl_clk0]] != 200000000} {error "Actual BD clock is not200MHz"}
if {abs([get_property CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ $ps]-200.0)>0.000001} {error "PS PL0 actual frequency is not200MHz"}
save_bd_design
write_bd_tcl -force [file join $out qwen_system.tcl]
set f [open [file join $out address_map.txt] w]
foreach s [get_bd_addr_segs] {puts $f "$s [get_property OFFSET $s] [get_property RANGE $s]"}
close $f
if {$stage eq "validate"} {puts "PASS_BOARD_COMPOSITION_ONLY";exit}
generate_target all [get_files qwen_system.bd]
set wrapper [make_wrapper -files [get_files qwen_system.bd] -top]
add_files -norecurse $wrapper
set_property top qwen_system_wrapper [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Board synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Board implementation/bitstream failed"}
open_run impl_1
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $out timing_summary.rpt]
report_utilization -hierarchical -file [file join $out utilization_hierarchical.rpt]
report_utilization -file [file join $out utilization.rpt]
report_drc -file [file join $out drc.rpt]
report_methodology -file [file join $out methodology.rpt]
report_clock_interaction -file [file join $out clock_interaction.rpt]
report_clocks -file [file join $out clocks.rpt]
write_checkpoint -force [file join $out routed.dcp]
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
set f [open [file join $out routed_result.txt] w]
puts $f "part=xczu7ev-ffvc1156-2-e\nnominal_PL_clock_MHz=200\nsetup_slack_ns=$wns\nhold_slack_ns=$whs\nphysical_board_test=not_performed"
close $f
if {$wns < 0 || $whs < 0} {error "200MHz integrated timing failed; no publication"}
set bit [file join $out project qwen_zcu104.runs impl_1 qwen_system_wrapper.bit]
file copy -force $bit [file join $out qwen.bit]
set hwh [file join $out project qwen_zcu104.gen sources_1 bd qwen_system hw_handoff qwen_system.hwh]
file copy -force $hwh [file join $out qwen.hwh]
write_hw_platform -fixed -include_bit -force -file [file join $out qwen.xsa]
puts "PASS_ROUTED_ARTIFACT_BUILD_ONLY_NO_BOARD_TEST"
