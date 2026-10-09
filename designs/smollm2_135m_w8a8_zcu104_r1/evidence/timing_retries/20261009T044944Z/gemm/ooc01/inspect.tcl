set_param general.maxThreads 4
open_checkpoint /home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/timing_retries/20261009T044944Z/gemm/ooc01/executor_synth.dcp
report_clocks -file clocks_synth.rpt
report_timing -delay_type max -max_paths 20 -nworst 1 -file top_setup_paths.rpt
set f [open physical_mapping.tsv w]
puts $f "scope\tprimitive\tcount"
foreach scope {* dots/* output_conversion/* *a_low* *a_high* *result_fifo* *b_panels* *psum*} {
 foreach primitive {DSP48E2 RAMB36E2 RAMB18E2 URAM288 FDRE FDSE RAM32M RAM64M RAMD32 RAMS32 RAMD64E RAMS64E} {
  set cells [get_cells -hierarchical -quiet -filter "NAME =~ $scope && REF_NAME == $primitive"]
  puts $f "$scope\t$primitive\t[llength $cells]"
 }
}
close $f
set f [open primitive_cells.tsv w]
puts $f "name\tref"
foreach cell [get_cells -hierarchical -quiet -filter {REF_NAME == DSP48E2 || REF_NAME == RAMB36E2 || REF_NAME == RAMB18E2 || REF_NAME =~ URAM* || REF_NAME =~ RAMD* || REF_NAME =~ RAMS*}] {puts $f "$cell\t[get_property REF_NAME $cell]"}
close $f
puts GEMM_NETLIST_INSPECTION_COMPLETE
exit
