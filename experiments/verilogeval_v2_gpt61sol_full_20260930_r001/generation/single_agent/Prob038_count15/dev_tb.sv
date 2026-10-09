`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 1;
    wire [3:0] q;
    integer expected = 0;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    task automatic tick_check;
        @(posedge clk);
        if (reset) expected = 0;
        else expected = (expected + 1) % 16;
        #1;
        if (q !== expected[3:0])
            $fatal(1, "Mismatch: expected %0d, got %0d", expected, q);
        checks = checks + 1;
    endtask

    initial begin
        tick_check();
        tick_check();
        @(negedge clk); reset = 0;
        repeat (40) tick_check();
        @(negedge clk);
        #1; reset = 1;
        #1;
        if (q !== expected[3:0]) $fatal(1, "Reset acted asynchronously");
        tick_check();
        tick_check();
        @(negedge clk); reset = 0;
        repeat (32) tick_check();
        $display("PASS: %0d rising-edge checks; wraparound and synchronous reset verified", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Testbench timeout");
    end
endmodule
