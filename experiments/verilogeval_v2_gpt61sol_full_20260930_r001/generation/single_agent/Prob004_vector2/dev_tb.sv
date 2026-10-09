`timescale 1ns/1ps
module dev_tb;
    logic [31:0] in;
    logic [31:0] out;
    logic [31:0] expected;
    integer checks = 0;
    TopModule dut (.in(in), .out(out));

    task automatic check(input logic [31:0] value);
        in = value;
        for (integer byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
            expected[byte_index*8 +: 8] = value[(3-byte_index)*8 +: 8];
        #1;
        if (out !== expected)
            $fatal(1, "FAIL input=%h expected=%h actual=%h", value, expected, out);
        checks = checks + 1;
    endtask

    initial begin
        check(32'h00000000);
        check(32'hffffffff);
        check(32'h12345678);
        check(32'h01234567);
        for (integer bit_index = 0; bit_index < 32; bit_index = bit_index + 1)
            check(32'h00000001 << bit_index);
        for (integer sample = 0; sample < 1000; sample = sample + 1)
            check($urandom);
        check(32'hxx12zz34);
        $display("PASS: %0d byte-reversal checks", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "FAIL: development timeout");
    end
endmodule
