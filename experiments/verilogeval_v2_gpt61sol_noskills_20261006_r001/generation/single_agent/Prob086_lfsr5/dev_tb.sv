`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [4:0] q;
    integer expected;
    integer i;
    reg [31:0] seen;
    reg [4:0] held;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    task tick;
        begin
            @(posedge clk);
            if (reset) expected = 1;
            else if ((expected & 1) != 0) expected = (expected >> 1) ^ 20;
            else expected = expected >> 1;
            #1;
            if (q !== expected[4:0])
                $fatal(1, "State mismatch: expected %0d, got %b", expected, q);
        end
    endtask

    initial begin
        #2;
        reset = 1;
        tick();
        tick();
        @(negedge clk);
        reset = 0;
        seen = 0;
        seen[1] = 1;
        for (i = 1; i <= 31; i = i + 1) begin
            tick();
            if (q == 0) $fatal(1, "Reached zero state");
            if (i < 31) begin
                if (seen[q]) $fatal(1, "Early repeated state %0d", q);
                seen[q] = 1;
            end else if (q !== 5'd1)
                $fatal(1, "Did not return to seed after 31 steps");
        end
        if (seen !== 32'hfffffffe) $fatal(1, "Missing nonzero states");
        repeat (7) tick();
        @(negedge clk);
        held = q;
        #1 reset = 1;
        #1;
        if (q !== held) $fatal(1, "Reset changed state before positive edge");
        tick();
        repeat (3) tick();
        @(negedge clk);
        reset = 0;
        repeat (62) tick();
        $display("PASS: synchronous reset, tap recurrence, and maximal-length cycle");
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
