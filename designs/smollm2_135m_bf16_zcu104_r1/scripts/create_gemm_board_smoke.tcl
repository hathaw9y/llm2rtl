set design_dir [file normalize [file join [file dirname [info script]] ..]]
set repo_dir [file normalize [file join $design_dir ../..]]
set project_dir [file join $design_dir build zcu104_gemm_board_smoke]
file mkdir $project_dir
create_project zcu104_gemm_board_smoke $project_dir -part xczu7ev-ffvc1156-2-e -force
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]

set source [file join $repo_dir ip infrastructure bank_ownership_table rtl bank_ownership_table.sv]
add_files $source
set_property file_type SystemVerilog [get_files $source]
foreach name [list bram_bank uram_bank] {
    set source [file join $repo_dir ip infrastructure datamover_engine rtl ${name}.sv]
    add_files $source
    set_property file_type SystemVerilog [get_files $source]
}
foreach name [list smollm2_bank_port_router_wide smollm2_bank_memories_wide \
                   smollm2_bank_subsystem_wide smollm2_gemm_systolic_wide_executor \
                   smollm2_gemm_board_smoke] {
    set source [file join $design_dir rtl ${name}.sv]
    add_files $source
    set_property file_type SystemVerilog [get_files $source]
}
add_files [file join $design_dir rtl smollm2_gemm_board_smoke_bd.v]
update_compile_order -fileset sources_1

create_bd_design system
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 ps]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {apply_board_preset "1"} $ps
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {200}] $ps

set interconnect [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {3}] $interconnect
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
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst]
set smoke [create_bd_cell -type module -reference smollm2_gemm_board_smoke_bd smoke]

connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_HPM0_FPD] [get_bd_intf_pins axi/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi/M00_AXI] [get_bd_intf_pins gpio_lo/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi/M01_AXI] [get_bd_intf_pins gpio_hi/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi/M02_AXI] [get_bd_intf_pins gpio_ctl/S_AXI]
connect_bd_net [get_bd_pins ps/pl_clk0] \
    [get_bd_pins ps/maxihpm0_fpd_aclk] [get_bd_pins axi/aclk] \
    [get_bd_pins gpio_lo/s_axi_aclk] [get_bd_pins gpio_hi/s_axi_aclk] \
    [get_bd_pins gpio_ctl/s_axi_aclk] [get_bd_pins rst/slowest_sync_clk] \
    [get_bd_pins smoke/aclk]
connect_bd_net [get_bd_pins ps/pl_resetn0] [get_bd_pins rst/ext_reset_in]
connect_bd_net [get_bd_pins rst/peripheral_aresetn] \
    [get_bd_pins axi/aresetn] [get_bd_pins gpio_lo/s_axi_aresetn] \
    [get_bd_pins gpio_hi/s_axi_aresetn] [get_bd_pins gpio_ctl/s_axi_aresetn] \
    [get_bd_pins smoke/aresetn]
connect_bd_net [get_bd_pins gpio_lo/gpio_io_o] [get_bd_pins smoke/host_data0]
connect_bd_net [get_bd_pins gpio_lo/gpio2_io_o] [get_bd_pins smoke/host_data1]
connect_bd_net [get_bd_pins gpio_hi/gpio_io_o] [get_bd_pins smoke/host_data2]
connect_bd_net [get_bd_pins gpio_hi/gpio2_io_o] [get_bd_pins smoke/host_data3]
connect_bd_net [get_bd_pins gpio_ctl/gpio_io_o] [get_bd_pins smoke/host_control]
connect_bd_net [get_bd_pins smoke/host_status] [get_bd_pins gpio_ctl/gpio2_io_i]

assign_bd_address
validate_bd_design
save_bd_design
set bd [get_files [file join $project_dir zcu104_gemm_board_smoke.srcs sources_1 bd system system.bd]]
generate_target all $bd
make_wrapper -files $bd -top
add_files -norecurse [file join $project_dir zcu104_gemm_board_smoke.gen sources_1 bd system hdl system_wrapper.v]
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1
puts "BOARD_PROJECT $project_dir"
