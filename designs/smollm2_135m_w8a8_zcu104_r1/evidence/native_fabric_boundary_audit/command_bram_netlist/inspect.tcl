open_checkpoint {/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/command_bram/ooc_001/command_bram.dcp}
set f [open primitive_mapping.tsv w]
puts $f "name\tref\tDOA_REG\tDOB_REG\tREAD_WIDTH_A\tREAD_WIDTH_B\tWRITE_WIDTH_A\tWRITE_WIDTH_B\tCLKARDCLK_clock\tCLKBWRCLK_clock"
foreach c [get_cells -hier -filter {REF_NAME =~ RAMB*}] {
 set vals [list $c [get_property REF_NAME $c]]
 foreach p {DOA_REG DOB_REG READ_WIDTH_A READ_WIDTH_B WRITE_WIDTH_A WRITE_WIDTH_B} {lappend vals [get_property $p $c]}
 foreach pin {CLKARDCLK CLKBWRCLK} {lappend vals [get_clocks -of_objects [get_pins $c/$pin]]}
 puts $f [join $vals \t]
}
close $f
report_clocks -file clocks.rpt
puts "AUDIT_COMMAND_BRAM_NETLIST_INSPECTED"
exit
