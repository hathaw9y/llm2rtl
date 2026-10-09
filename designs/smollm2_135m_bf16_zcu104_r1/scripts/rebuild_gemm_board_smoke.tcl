set design_dir [file normalize [file join [file dirname [info script]] ..]]
set project_dir [file join $design_dir build zcu104_gemm_board_smoke]
open_project [file join $project_dir zcu104_gemm_board_smoke.xpr]
foreach run_name [list impl_1 synth_1 system_smoke_0_synth_1] {
    set run [get_runs -quiet $run_name]
    if {[llength $run] != 0} {
        reset_run $run_name
    }
}
close_project
source [file join $design_dir scripts build_gemm_board_smoke.tcl]
