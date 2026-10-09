`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic ar = 0;
    logic d = 0;
    wire q;
    TopModule dut (.clk(clk), .ar(ar), .d(d), .q(q));
    task automatic check(input logic expected);
        if (q !== expected) $fatal(1, "FAIL: q=%b expected=%b", q, expected);
    endtask
    initial begin
        #1 ar = 1;
        #1 check(0);
        d = 1;
        #1 clk = 1;
        #1 check(0);
        clk = 0; ar = 0;
        #1 check(0);
        clk = 1;
        #1 check(1);
        d = 0;
        #1 check(1);
        clk = 0;
        #1 check(1);
        clk = 1;
        #1 check(0);
        clk = 0; d = 1;
        #1 clk = 1;
        #1 check(1);
        #1 ar = 1;
        #1 check(0);
        ar = 0;
        #1 check(0);
        clk = 0;
        #1 clk = 1;
        #1 check(1);
        $display("PASS: capture, hold, reset priority, asynchronous reset, and release");
        $finish;
    end
    initial begin
        #100 $fatal(1, "FAIL: timeout");
    end
endmodule
