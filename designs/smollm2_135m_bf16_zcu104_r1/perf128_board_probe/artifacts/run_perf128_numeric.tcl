set artifact_dir [file dirname [file normalize [info script]]]
set bit_file [file join $artifact_dir zcu104_perf128_board_probe.bit]
set elf_file [file join $artifact_dir smollm2_gemm_tiles_numeric_sd.elf]
set ps_init_file [file join $artifact_dir psu_init.tcl]
foreach path [list $bit_file $elf_file $ps_init_file] {
    if {![file isfile $path]} {error "Missing artifact: $path"}
}
connect
targets -set -filter {name =~ "Cortex-A53 #0"}
catch {stop}
rst -processor
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
puts "Starting profile-bitstream numerical probe; capture UART at 115200."
con
after 10000
