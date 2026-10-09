set out [file normalize [lindex $argv 0]]
set_param general.maxThreads 2
open_project [file join $out project qwen_zcu104.xpr]
# Work only in the fresh clone; never write a prior build's run directory.
set run_dir [file normalize [get_property DIRECTORY [get_runs impl_1]]]
if {[string first "$out/" "$run_dir/"] != 0} {error "Cloned implementation directory points outside fresh build"}
file copy -force [file join $out routed.dcp] [file join $run_dir qwen_system_wrapper_routed.dcp]
open_run impl_1
set plclock [get_clocks clk_pl_0]
if {[llength $plclock] != 1 || abs([get_property PERIOD $plclock]-5.0)>0.000001} {error "Wrong 200MHz clock contract"}
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $out timing_before_continuation.rpt]
phys_opt_design -directive AggressiveExplore
if {[get_property SLACK [get_timing_paths -delay_type max -max_paths 1]] < 0} {
    phys_opt_design -directive Explore
}
report_route_status -file [file join $out route_status.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $out timing_summary.rpt]
report_utilization -hierarchical -file [file join $out utilization_hierarchical.rpt]
report_utilization -file [file join $out utilization.rpt]
report_drc -file [file join $out drc.rpt]
report_methodology -file [file join $out methodology.rpt]
report_clock_interaction -file [file join $out clock_interaction.rpt]
report_clocks -file [file join $out clocks.rpt]
write_checkpoint -force [file join $out routed.dcp]
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
set f [open [file join $out routed_result.txt] w]
puts $f "part=xczu7ev-ffvc1156-2-e\nnominal_PL_clock_MHz=200\nsetup_slack_ns=$wns\nhold_slack_ns=$whs\nphysical_board_test=not_performed"
close $f
if {$wns < 0 || $whs < 0} {error "200MHz post-route timing failed; no publication"}
write_bitstream -force [file join $out qwen.bit]
# write_hw_platform uses the project's completed implementation bitstream.
# Replace that clone's BIT with the exact checkpoint's freshly generated BIT.
file copy -force [file join $out qwen.bit] [file join $run_dir qwen_system_wrapper.bit]
file copy -force [file join $out routed.dcp] [file join $run_dir qwen_system_wrapper_routed.dcp]
set hwh [file join $out project qwen_zcu104.gen sources_1 bd qwen_system hw_handoff qwen_system.hwh]
file copy -force $hwh [file join $out qwen.hwh]
write_hw_platform -fixed -include_bit -force -file [file join $out qwen.xsa]
puts "PASS_POST_ROUTE_ARTIFACT_BUILD_ONLY_NO_BOARD_TEST"
