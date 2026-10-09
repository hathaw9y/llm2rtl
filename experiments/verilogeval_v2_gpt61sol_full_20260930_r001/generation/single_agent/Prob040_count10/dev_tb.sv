`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 1;
    wire [3:0] q;
    integer expected = 0;
    integer cycles = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;
    task automatic step(input logic rst);
        @(negedge clk);
        reset = rst;
        #1;
        if (q !== expected[3:0]) $fatal(1, "Output changed between clock edges");
        @(posedge clk);
        expected = rst ? 0 : (expected + 1) % 10;
        #1;
        if (q !== expected[3:0])
            $fatal(1, "cycle %0d expected %0d got %0d", cycles, expected, q);
        cycles = cycles + 1;
    endtask
    initial begin
        @(posedge clk);
        #1;
        if (q !== 4'd0) $fatal(1, "Initial synchronous reset failed");
        repeat (35) step(0);
        step(1);
        repeat (3) step(1);
        repeat (24) step(0);
        step(1);
        repeat (20) step(0);
        $display("PASS: %0d checked cycles, wraparound and synchronous reset", cycles);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
