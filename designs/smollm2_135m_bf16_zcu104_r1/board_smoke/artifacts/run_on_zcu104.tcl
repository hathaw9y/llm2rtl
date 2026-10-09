# Run from the host PC with: xsct run_on_zcu104.tcl
# The ZCU104 must be powered in JTAG boot mode and connected to this PC.
set artifact_dir [file dirname [file normalize [info script]]]
set bit_file [file join $artifact_dir zcu104_gemm_board_smoke.bit]
set elf_file [file join $artifact_dir zcu104_gemm_board_smoke.elf]
set ps_init_file [file join $artifact_dir psu_init.tcl]
foreach path [list $bit_file $elf_file $ps_init_file] {
    if {![file isfile $path]} { error "Missing artifact: $path" }
}

connect
targets
targets -set -filter {name =~ "PSU"}
fpga $bit_file
source $ps_init_file
psu_init
after 1000
psu_ps_pl_isolation_removal
after 1000
psu_ps_pl_reset_config
targets -set -filter {name =~ "Cortex-A53 #0"}
rst -processor
dow $elf_file
puts "Starting A53-0. Observe psu_uart_0 at 115200 8-N-1."
con
after 10000
