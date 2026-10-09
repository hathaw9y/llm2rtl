# Run from this artifacts directory: xsct -nodisp run_on_zcu104.tcl
set artifact_dir [file dirname [file normalize [info script]]]
set bit_file [file join $artifact_dir zcu104_first_layer_kv_board_probe.bit]
set elf_file [file join $artifact_dir smollm2_full_model_30_layer_probe.elf]
set ps_init_file [file join $artifact_dir psu_init.tcl]
set ddr_file [file join $artifact_dir .. ddr_static_bf16.bin]
foreach path [list $bit_file $elf_file $ps_init_file $ddr_file] {
    if {![file isfile $path]} {error "Missing artifact: $path"}
}
connect
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
puts "Loading 269161088 static BF16 bytes to DDR at 0x57A00000..."
dow -data $ddr_file 0x57A00000
puts "Static DDR load finished. Downloading ISA control app..."
dow $elf_file
puts "Starting A53-0; capture psu_uart_0 at 115200 8-N-1."
con
after 10000
