`timescale 1ns/1ps
module tb_full_ffn_tap;
  logic clk=0;
  always #5 clk=~clk;
  logic write_enable=0, read_enable=0;
  logic [12:0] write_address=0, read_address=0;
  logic [15:0] write_strb=0;
  logic [127:0] write_data=0, read_data;
  smollm2_full_ffn_tap dut (.*);
  initial begin
    @(negedge clk);
    write_enable=1; write_address=13'd6143; write_strb=16'hffff;
    write_data=128'h0008_0007_0006_0005_0004_0003_0002_0001;
    @(negedge clk);
    write_address=13'd6143; write_strb=16'h000c;
    write_data=128'hffff_ffff_ffff_ffff_ffff_ffff_1234_ffff;
    @(negedge clk);
    write_enable=0; read_enable=1; read_address=13'd6143;
    @(negedge clk);
    if (read_data !== 128'h0008_0007_0006_0005_0004_0003_1234_0001)
      $fatal(1,"lane mask at final FFN word failed: %h",read_data);
    $display("FULL_FFN_TAP PASS");
    $finish;
  end
endmodule
