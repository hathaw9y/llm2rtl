# Run from existing full_model_board_probe/artifacts/interactive.
set interactive_dir [file dirname [file normalize [info script]]]
set artifact_dir [file dirname $interactive_dir]
set bit_file [file join $artifact_dir zcu104_first_layer_kv_board_probe.bit]
set ps_init_file [file join $artifact_dir psu_init.tcl]
set elf_file [file join $interactive_dir smollm2_interactive_sd.elf]
foreach path [list $bit_file $ps_init_file $elf_file] {
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
puts "Starting SmolLM2 interactive app. Connect host ask.py to PS UART 115200."
con
after 10000
