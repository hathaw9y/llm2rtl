`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [3:0] q;
    integer expected;
    integer cycles = 0;
    integer i;
    TopModule dut(.clk(clk), .reset(reset), .q(q));

    task tick;
        begin
            #2;
            clk = 1;
            if (reset) expected = 0;
            else expected = (expected + 1) % 10;
            #1;
            if (q !== expected[3:0])
                $fatal(1, "Cycle %0d expected %0d got %b", cycles, expected, q);
            cycles = cycles + 1;
            clk = 0;
            #1;
            if (q !== expected[3:0]) $fatal(1, "Output changed at falling edge");
        end
    endtask

    initial begin
        // Establish the specified state by synchronous reset; power-up is unspecified.
        reset = 1;
        tick;
        tick;
        reset = 0;
        for (i = 0; i < 35; i = i + 1) tick;
        // Reset asserted between edges must not change the output.
        reset = 1;
        #1;
        if (q !== 4'd5) $fatal(1, "Reset acted asynchronously");
        tick;
        tick;
        reset = 0;
        for (i = 0; i < 9; i = i + 1) tick;
        // Reset has priority at the terminal count.
        reset = 1;
        #1;
        if (q !== 4'd9) $fatal(1, "Terminal count changed before clock");
        tick;
        reset = 0;
        for (i = 0; i < 21; i = i + 1) tick;
        // A reset pulse entirely between rising edges is ignored.
        reset = 1;
        #1;
        if (q !== 4'd1) $fatal(1, "Between-edge reset changed output");
        reset = 0;
        tick;
        $display("PASS: decade count, wraparound, synchronous reset and reset priority (%0d cycles)", cycles);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
