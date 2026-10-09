set design_dir [file normalize [file join [file dirname [info script]] ..]]
set evidence_dir [file join $design_dir evidence smollm2_silu_mul_executor run_001]
file mkdir $evidence_dir
create_project -in_memory -part xczu7ev-ffvc1156-2-e
read_verilog -sv [file join $design_dir rtl smollm2_silu_mul_executor.sv]
add_files [file join $design_dir rtl smollm2_silu_bf16_lut.mem]
cd [file join $design_dir rtl]
synth_design -top smollm2_silu_mul_executor -mode out_of_context \
    -part xczu7ev-ffvc1156-2-e
create_clock -name aclk -period 10.000 [get_ports aclk]
opt_design
place_design
report_timing_summary -file [file join $evidence_dir ooc_100mhz_timing.rpt]
report_utilization -file [file join $evidence_dir ooc_100mhz_utilization.rpt]
report_timing -max_paths 5 -file [file join $evidence_dir ooc_100mhz_top5.rpt]
