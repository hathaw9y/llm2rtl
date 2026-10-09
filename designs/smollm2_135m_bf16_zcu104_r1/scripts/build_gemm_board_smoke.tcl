set design_dir [file normalize [file join [file dirname [info script]] ..]]
set project_dir [file join $design_dir build zcu104_gemm_board_smoke]
set artifact_dir [file join $design_dir board_smoke artifacts]
file mkdir $artifact_dir
open_project [file join $project_dir zcu104_gemm_board_smoke.xpr]

launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "SYNTH_STATUS $synth_status"
if {![string match {*Complete*} $synth_status]} {
    error "Board synthesis failed: $synth_status"
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "IMPL_STATUS $impl_status"
if {![string match {*Complete*} $impl_status]} {
    error "Board implementation failed: $impl_status"
}

open_run impl_1
report_timing_summary -file [file join $artifact_dir routed_timing_summary.rpt]
report_utilization -file [file join $artifact_dir routed_utilization.rpt]
report_drc -file [file join $artifact_dir routed_drc.rpt]
set timing_bad [get_timing_paths -max_paths 1 -setup -slack_lesser_than 0]
if {[llength $timing_bad] != 0} {
    puts "ROUTED_TIMING_FAIL [get_property SLACK [lindex $timing_bad 0]]"
} else {
    puts "ROUTED_TIMING_PASS"
}

set bitfile [file join [get_property DIRECTORY [get_runs impl_1]] system_wrapper.bit]
if {![file exists $bitfile]} {
    error "Bitstream missing: $bitfile"
}
file copy -force $bitfile [file join $artifact_dir zcu104_gemm_board_smoke.bit]
write_hw_platform -fixed -include_bit -force \
    -file [file join $artifact_dir zcu104_gemm_board_smoke.xsa]
puts "BOARD_ARTIFACT_DIR $artifact_dir"
