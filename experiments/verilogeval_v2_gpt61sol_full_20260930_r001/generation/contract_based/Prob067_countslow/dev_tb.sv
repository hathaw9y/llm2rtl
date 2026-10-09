`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic slowena = 0;
    wire [3:0] q;
    integer expected = 0;
    integer checks = 0;
    integer i, j;
    logic [15:0] stimulus = 16'hb491;
    TopModule dut (.clk(clk), .reset(reset), .slowena(slowena), .q(q));
    always #5 clk = ~clk;

    task automatic step(input logic rst, input logic ena);
        @(negedge clk);
        reset = rst;
        slowena = ena;
        #1;
        if (q !== expected[3:0])
            $fatal(1, "Between-edge mismatch: expected %0d got %0d", expected, q);
        @(posedge clk);
        if (rst) expected = 0;
        else if (ena) expected = (expected + 1) % 10;
        #1;
        if (q !== expected[3:0])
            $fatal(1, "Cycle mismatch: reset=%b enable=%b expected=%0d got=%0d", rst, ena, expected, q);
        checks = checks + 1;
    endtask

    initial begin
        reset = 1;
        @(posedge clk);
        #1;
        if (q !== 4'd0) $fatal(1, "Initial synchronous reset failed");
        checks = checks + 1;
        step(1, 0);
        step(1, 1);
        for (i = 0; i < 40; i = i + 1) step(0, 1);
        for (i = 0; i < 10; i = i + 1) begin
            for (j = 0; j < 3; j = j + 1) step(0, 0);
            step(0, 1);
        end
        step(0, 1);
        step(0, 1);
        step(1, 0);
        step(0, 1);
        step(1, 1);
        for (i = 0; i < 300; i = i + 1) begin
            stimulus = {stimulus[14:0], stimulus[15] ^ stimulus[13] ^ stimulus[12] ^ stimulus[10]};
            step(stimulus[4:0] == 5'b11111, stimulus[8]);
        end
        $display("PASS: %0d checked rising edges; wrap, hold, reset priority and synchronous behavior", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Testbench timeout");
    end
endmodule
