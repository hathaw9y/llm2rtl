set design_dir [file normalize [file join [file dirname [info script]] ..]]
set project_dir [file join $design_dir build zcu104_gemm_board_smoke]
open_project [file join $project_dir zcu104_gemm_board_smoke.xpr]
set bd [get_files [file join $project_dir zcu104_gemm_board_smoke.srcs sources_1 bd system system.bd]]
open_bd_design $bd
set ps [get_bd_cells ps]
set_property CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL RPLL $ps
set_property CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ 200 $ps
validate_bd_design
set actual [get_property CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ $ps]
if {abs(double($actual) - 200.0) > 0.001} {
    error "PL0 clock is $actual MHz, expected 200 MHz"
}
save_bd_design
generate_target all $bd
puts "PL0_ACTUAL_FREQMHZ $actual"
