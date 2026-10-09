`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [3:0] q;
    integer expected = 0;
    integer checks = 0;
    integer phase;
    integer step;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    task automatic tick(input logic rst);
        @(negedge clk);
        reset = rst;
        #1;
        if (checks > 0 && q !== expected[3:0])
            $fatal(1, "Output changed between edges");
        @(posedge clk);
        if (rst) expected = 0;
        else expected = (expected + 1) % 10;
        #1;
        if (q !== expected[3:0])
            $fatal(1, "Expected %0d, got %0d", expected, q);
        checks = checks + 1;
    endtask

    initial begin
        tick(1);
        tick(1);
        tick(1);
        for (step = 0; step < 50; step = step + 1) tick(0);
        for (phase = 0; phase < 10; phase = phase + 1) begin
            tick(1);
            for (step = 0; step < phase; step = step + 1) tick(0);
            tick(1);
        end
        tick(0);
        @(negedge clk);
        #1 reset = 1;
        #1;
        if (q !== expected[3:0]) $fatal(1, "Reset acted asynchronously");
        reset = 0;
        #1;
        if (q !== expected[3:0]) $fatal(1, "Output changed after inter-edge pulse");
        @(posedge clk);
        expected = (expected + 1) % 10;
        #1;
        if (q !== expected[3:0]) $fatal(1, "Pulse incorrectly reset count");
        for (step = 0; step < 30; step = step + 1) tick(0);
        $display("PASS: decade sequence, reset at every legal count, held reset, synchronous pulse, and stability (%0d checked ticks)", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Watchdog timeout");
    end
endmodule
