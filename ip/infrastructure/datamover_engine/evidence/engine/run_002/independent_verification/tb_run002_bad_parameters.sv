`timescale 1ns/1ps
module tb_bad_ddr_alignment;
  datamover_command_queue #(.BANK_NUM(1), .BANK_WIDTH(1), .DDR_ALIGN_BYTES(3)) dut();
  initial begin #10; $fatal(1,"DDR power-of-two assertion did not fire"); end
endmodule

module tb_bad_bank_word;
  datamover_command_queue #(.BANK_NUM(1), .BANK_WIDTH(1),
    .BANK_WORD_BYTES(32'd12), .BANK_CAPACITY_BYTES(32'd64)) dut();
  initial begin #10; $fatal(1,"bank-word power-of-two assertion did not fire"); end
endmodule
