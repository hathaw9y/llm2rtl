`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic ar = 0;
    logic d = 0;
    wire q;
    integer checks = 0;
    TopModule dut (.clk(clk), .ar(ar), .d(d), .q(q));

    task automatic check(input logic expected);
        #1;
        checks = checks + 1;
        if (q !== expected)
            $fatal(1, "FAIL check %0d: q=%b expected=%b", checks, q, expected);
    endtask

    initial begin
        #1; ar = 1; check(0);
        d = 1; check(0);
        clk = 1; check(0);
        clk = 0; check(0);
        ar = 0; check(0);
        clk = 1; check(1);
        d = 0; check(1);
        clk = 0; check(1);
        clk = 1; check(0);
        clk = 0; d = 1; check(0);
        clk = 1; check(1);
        // Reset assertion away from a clock edge must immediately clear q.
        ar = 1; check(0);
        ar = 0; check(0);
        clk = 0; check(0);
        clk = 1; check(1);
        clk = 0; check(1);
        ar = 1; check(0);
        clk = 1; check(0);
        ar = 0; check(0);
        clk = 0; d = 0; check(0);
        clk = 1; check(0);
        $display("PASS: %0d directed checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
