`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [9:0] q;
    integer expected;
    integer cycles = 0;
    integer wraps = 0;
    reg valid = 0;
    reg [9:0] held;

    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            expected = 0;
            valid = 1;
        end else if (valid) begin
            expected = (expected + 1) % 1000;
            if (expected == 0) wraps = wraps + 1;
        end
        #1;
        if (valid && q !== expected[9:0])
            $fatal(1, "Cycle %0d: expected %0d, got %0d", cycles, expected, q);
        cycles = cycles + 1;
    end

    initial begin
        // Establish state using a synchronous reset, away from clock edges.
        #2; reset = 1;
        @(negedge clk); reset = 0;
        // Check three complete periods, including 998 -> 999 -> 0.
        repeat (3000) @(negedge clk);
        if (wraps != 3) $fatal(1, "Expected three wraps, got %0d", wraps);
        repeat (137) @(negedge clk);
        held = q;
        #2; reset = 1;
        #1;
        if (q !== held) $fatal(1, "Reset changed q before a positive clock edge");
        @(negedge clk);
        if (q !== 10'd0) $fatal(1, "Reset failed");
        repeat (3) @(negedge clk);
        if (q !== 10'd0) $fatal(1, "Held reset failed");
        reset = 0;
        repeat (1001) @(negedge clk);
        if (q !== 10'd1) $fatal(1, "Restart period failed");
        // A reset pulse with no positive edge must have no effect.
        held = q;
        #1; reset = 1;
        #1; reset = 0;
        #1;
        if (q !== held) $fatal(1, "Reset pulse asynchronously changed state");
        repeat (10) @(negedge clk);
        $display("PASS: counter periods, boundary transitions, and synchronous reset");
        $finish;
    end
    initial begin
        #50000;
        $fatal(1, "Timeout");
    end
endmodule
