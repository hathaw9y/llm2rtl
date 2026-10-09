`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic slowena = 0;
    logic [3:0] q;
    integer expected = 0;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .slowena(slowena), .q(q));
    always #5 clk = ~clk;

    task automatic step(input bit rst, input bit ena);
        @(negedge clk);
        reset = rst;
        slowena = ena;
        #1;
        if (checks > 0 && q !== expected[3:0])
            $fatal(1, "Output changed between rising edges");
        @(posedge clk);
        if (rst) expected = 0;
        else if (ena) expected = (expected + 1) % 10;
        #1;
        if (q !== expected[3:0])
            $fatal(1, "Mismatch: reset=%b enable=%b expected=%0d q=%0d", rst, ena, expected, q);
        checks = checks + 1;
    endtask

    initial begin
        step(1, 0);
        repeat (25) step(0, 1);
        repeat (5) step(0, 0);
        step(1, 1);
        repeat (10) step(0, 1);
        repeat (100) begin
            step(0, 0);
            step(0, 1);
            step(0, 1);
        end
        step(1, 0);
        step(0, 0);
        $display("PASS: %0d checked cycles", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Testbench timeout");
    end
endmodule
