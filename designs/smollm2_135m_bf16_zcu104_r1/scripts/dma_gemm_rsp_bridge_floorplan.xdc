# Keep the router-to-GEMM response registers near the middle of the
# source-to-tile-buffer route. The unconstrained build placed activation
# registers at SLICE_X74Y40 and tile registers at SLICE_X15Y272.
create_pblock rsp_bridge_mid
add_cells_to_pblock [get_pblocks rsp_bridge_mid] [get_cells -hier -filter {
    NAME =~ *act_rsp_data_r_reg* || NAME =~ *weight_rsp_data_r_reg* ||
    NAME =~ *act_rsp_bank_r_reg* || NAME =~ *weight_rsp_bank_r_reg* ||
    NAME =~ *act_rsp_valid_r_reg* || NAME =~ *weight_rsp_valid_r_reg*
}]
resize_pblock [get_pblocks rsp_bridge_mid] -add {SLICE_X35Y110:SLICE_X55Y190}
set_property IS_SOFT false [get_pblocks rsp_bridge_mid]
