`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    logic out;
    TopModule dut (.a(a), .b(b), .out(out));
    initial begin
        a = 0; b = 0; #1;
        if (out !== 1'b0) $fatal(1, "00 failed");
        a = 0; b = 1; #1;
        if (out !== 1'b0) $fatal(1, "01 failed");
        a = 1; b = 0; #1;
        if (out !== 1'b0) $fatal(1, "10 failed");
        a = 1; b = 1; #1;
        if (out !== 1'b1) $fatal(1, "11 failed");
        $display("PASS: all four AND gate input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Testbench timeout");
    end
endmodule
