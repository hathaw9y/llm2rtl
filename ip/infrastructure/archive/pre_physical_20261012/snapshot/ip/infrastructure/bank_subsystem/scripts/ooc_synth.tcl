set repo_root [file normalize [file join [file dirname [info script]] ../../../..]]
set out_dir [file normalize [lindex $argv 0]]
file mkdir $out_dir
read_verilog -sv [file join $repo_root ip/infrastructure/bank_sparse_router/rtl/bank_config_pkg.sv]
read_verilog -sv [file join $repo_root ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv]
read_verilog -sv [file join $repo_root ip/infrastructure/bank_sparse_router/rtl/bank_sparse_router.sv]
read_verilog -sv [file join $repo_root ip/infrastructure/datamover_engine/rtl/bram_bank.sv]
read_verilog -sv [file join $repo_root ip/infrastructure/datamover_engine/rtl/uram_bank.sv]
read_verilog -sv [file join $repo_root ip/infrastructure/bank_subsystem/rtl/bank_subsystem.sv]
synth_design -top bank_subsystem -part xczu7ev-ffvc1156-2-e -mode out_of_context
create_clock -name aclk -period 5.000 [get_ports aclk]
report_timing_summary -delay_type min_max -max_paths 20 -file [file join $out_dir timing_summary.rpt]
report_utilization -hierarchical -file [file join $out_dir utilization.rpt]
report_drc -file [file join $out_dir drc.rpt]
report_methodology -file [file join $out_dir methodology.rpt]
report_ram_utilization -file [file join $out_dir ram_utilization.rpt]
write_checkpoint -force [file join $out_dir bank_subsystem_ooc.dcp]

