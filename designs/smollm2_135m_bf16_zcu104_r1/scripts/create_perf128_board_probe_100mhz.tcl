set design_dir [file normalize [file join [file dirname [info script]] ..]]
set repo_dir [file normalize [file join $design_dir ../..]]
set project_dir [file join $design_dir build zcu104_perf128_board_probe_100mhz]
if {[info exists ::env(SMOLLM2_PROFILE_BUILD_DIR)]} {
    set project_dir [file normalize $::env(SMOLLM2_PROFILE_BUILD_DIR)]
}
file mkdir $project_dir
create_project zcu104_perf128_board_probe_100mhz $project_dir -part xczu7ev-ffvc1156-2-e -force
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]

foreach name [list datamover_engine_pkg fifo pipeline axis_width_up_converter \
                   axis_width_down_converter axis_width_converter mm2s_adapter \
                   s2mm_adapter datamover_command_queue mm2s_channel \
                   s2mm_channel datamover_engine bram_bank uram_bank] {
    set source [file join $repo_dir ip infrastructure datamover_engine rtl ${name}.sv]
    add_files $source
    set_property file_type SystemVerilog [get_files $source]
}
set source [file join $repo_dir ip infrastructure bank_ownership_table rtl bank_ownership_table.sv]
add_files $source
set_property file_type SystemVerilog [get_files $source]
foreach name [list smollm2_bank_port_router_wide smollm2_bank_memories_wide \
                   smollm2_bank_subsystem_wide smollm2_dma_bank_bridge \
                   smollm2_dma_engine_link bank_tensor_state_tracker \
                   isa_command_dispatcher smollm2_dma_control_fabric_wide \
                   smollm2_gemm_systolic_wide_executor smollm2_rmsnorm_executor smollm2_rope_executor smollm2_softmax_executor smollm2_add_executor smollm2_silu_mul_executor \
                   smollm2_gemm_dma_fabric_wide \
                   smollm2_perf_counters smollm2_dma_gemm_board_probe] {
    set source [file join $design_dir rtl ${name}.sv]
    add_files $source
    set_property file_type SystemVerilog [get_files $source]
}
set silu_lut [file join $design_dir rtl smollm2_silu_bf16_lut.mem]
add_files $silu_lut
set_property include_dirs [list [file join $design_dir rtl]] [get_filesets sources_1]
set lut_header [file join $design_dir rtl smollm2_softmax_exp_lut.svh]
add_files $lut_header
set_property file_type {Verilog Header} [get_files $lut_header]
update_compile_order -fileset sources_1
set rsp_floorplan [file join $design_dir scripts dma_gemm_rsp_bridge_floorplan.xdc]
add_files -fileset constrs_1 $rsp_floorplan
set_property USED_IN_SYNTHESIS false [get_files $rsp_floorplan]
add_files [file join $design_dir rtl smollm2_perf128_board_probe_bd.v]
update_compile_order -fileset sources_1

create_bd_design system
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 ps]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {apply_board_preset "1"} $ps
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__S_AXI_GP2 {1} \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100}] $ps

set ctrl_axi [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 ctrl_axi]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {3}] $ctrl_axi
set mem_axi [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 mem_axi]
set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {1}] $mem_axi
set gpio_lo [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 gpio_lo]
set gpio_hi [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 gpio_hi]
set gpio_ctl [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 gpio_ctl]
foreach gpio [list $gpio_lo $gpio_hi] {
    set_property -dict [list CONFIG.C_IS_DUAL {1} CONFIG.C_GPIO_WIDTH {32} \
        CONFIG.C_GPIO2_WIDTH {32} CONFIG.C_ALL_OUTPUTS {1} \
        CONFIG.C_ALL_OUTPUTS_2 {1}] $gpio
}
set_property -dict [list CONFIG.C_IS_DUAL {1} CONFIG.C_GPIO_WIDTH {32} \
    CONFIG.C_GPIO2_WIDTH {32} CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_ALL_INPUTS_2 {1}] $gpio_ctl
set dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_datamover:5.1 dma]
set_property -dict [list CONFIG.c_enable_mm2s {1} CONFIG.c_enable_s2mm {1} \
    CONFIG.c_m_axi_mm2s_data_width {128} \
    CONFIG.c_m_axis_mm2s_tdata_width {128} \
    CONFIG.c_m_axi_s2mm_data_width {128} \
    CONFIG.c_s_axis_s2mm_tdata_width {128} \
    CONFIG.c_s2mm_btt_used {23} \
    CONFIG.c_mm2s_btt_used {23} CONFIG.c_addr_width {32}] $dma
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst]
set probe [create_bd_cell -type module -reference smollm2_perf128_board_probe_bd probe]

connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_HPM0_FPD] [get_bd_intf_pins ctrl_axi/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins ctrl_axi/M00_AXI] [get_bd_intf_pins gpio_lo/S_AXI]
connect_bd_intf_net [get_bd_intf_pins ctrl_axi/M01_AXI] [get_bd_intf_pins gpio_hi/S_AXI]
connect_bd_intf_net [get_bd_intf_pins ctrl_axi/M02_AXI] [get_bd_intf_pins gpio_ctl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins dma/M_AXI_MM2S] [get_bd_intf_pins mem_axi/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins dma/M_AXI_S2MM] [get_bd_intf_pins mem_axi/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins mem_axi/M00_AXI] [get_bd_intf_pins ps/S_AXI_HP0_FPD]

connect_bd_net [get_bd_pins ps/pl_clk0] \
    [get_bd_pins ps/maxihpm0_fpd_aclk] [get_bd_pins ps/saxihp0_fpd_aclk] \
    [get_bd_pins ctrl_axi/aclk] [get_bd_pins mem_axi/aclk] \
    [get_bd_pins gpio_lo/s_axi_aclk] [get_bd_pins gpio_hi/s_axi_aclk] \
    [get_bd_pins gpio_ctl/s_axi_aclk] \
    [get_bd_pins dma/m_axi_mm2s_aclk] \
    [get_bd_pins dma/m_axis_mm2s_cmdsts_aclk] \
    [get_bd_pins dma/m_axi_s2mm_aclk] \
    [get_bd_pins dma/m_axis_s2mm_cmdsts_awclk] \
    [get_bd_pins dma/s_axis_s2mm_cmdsts_aclk] \
    [get_bd_pins rst/slowest_sync_clk] [get_bd_pins probe/aclk]
connect_bd_net [get_bd_pins ps/pl_resetn0] [get_bd_pins rst/ext_reset_in]
connect_bd_net [get_bd_pins rst/peripheral_aresetn] \
    [get_bd_pins ctrl_axi/aresetn] [get_bd_pins mem_axi/aresetn] \
    [get_bd_pins gpio_lo/s_axi_aresetn] [get_bd_pins gpio_hi/s_axi_aresetn] \
    [get_bd_pins gpio_ctl/s_axi_aresetn] \
    [get_bd_pins dma/m_axi_mm2s_aresetn] \
    [get_bd_pins dma/m_axis_mm2s_cmdsts_aresetn] \
    [get_bd_pins dma/m_axi_s2mm_aresetn] \
    [get_bd_pins dma/s_axis_s2mm_cmdsts_aresetn] \
    [get_bd_pins probe/aresetn]

connect_bd_net [get_bd_pins gpio_lo/gpio_io_o] [get_bd_pins probe/host_data0]
connect_bd_net [get_bd_pins gpio_lo/gpio2_io_o] [get_bd_pins probe/host_data1]
connect_bd_net [get_bd_pins gpio_hi/gpio_io_o] [get_bd_pins probe/host_data2]
connect_bd_net [get_bd_pins gpio_hi/gpio2_io_o] [get_bd_pins probe/host_data3]
connect_bd_net [get_bd_pins gpio_ctl/gpio_io_o] [get_bd_pins probe/host_control]
connect_bd_net [get_bd_pins probe/host_status] [get_bd_pins gpio_ctl/gpio2_io_i]
connect_bd_net [get_bd_pins dma/mm2s_err] [get_bd_pins probe/datamover_mm2s_err]
connect_bd_net [get_bd_pins dma/s2mm_err] [get_bd_pins probe/datamover_s2mm_err]
connect_bd_intf_net [get_bd_intf_pins probe/m_axis_mm2s_cmd] \
    [get_bd_intf_pins dma/S_AXIS_MM2S_CMD]
connect_bd_intf_net [get_bd_intf_pins dma/M_AXIS_MM2S] \
    [get_bd_intf_pins probe/s_axis_mm2s]
connect_bd_intf_net [get_bd_intf_pins dma/M_AXIS_MM2S_STS] \
    [get_bd_intf_pins probe/s_axis_mm2s_sts]

connect_bd_intf_net [get_bd_intf_pins probe/m_axis_s2mm_cmd] \
    [get_bd_intf_pins dma/S_AXIS_S2MM_CMD]
connect_bd_intf_net [get_bd_intf_pins probe/m_axis_s2mm] \
    [get_bd_intf_pins dma/S_AXIS_S2MM]
connect_bd_intf_net [get_bd_intf_pins dma/M_AXIS_S2MM_STS] \
    [get_bd_intf_pins probe/s_axis_s2mm_sts]

assign_bd_address
foreach {name offset} {
    gpio_ctl 0xA0000000 gpio_hi 0xA0010000 gpio_lo 0xA0020000
} {
    set seg [get_bd_addr_segs ps/Data/SEG_${name}_Reg]
    if {[llength $seg] != 1} {error "Missing PS address segment for $name"}
    set_property offset $offset $seg
}
validate_bd_design
save_bd_design
set bd [get_files [file join $project_dir zcu104_perf128_board_probe_100mhz.srcs sources_1 bd system system.bd]]
generate_target all $bd
make_wrapper -files $bd -top
add_files -norecurse [file join $project_dir zcu104_perf128_board_probe_100mhz.gen sources_1 bd system hdl system_wrapper.v]
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1
puts "DMA_BOARD_PROJECT $project_dir"
