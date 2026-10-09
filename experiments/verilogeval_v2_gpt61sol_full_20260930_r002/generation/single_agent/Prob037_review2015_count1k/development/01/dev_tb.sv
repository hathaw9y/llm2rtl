`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [9:0] q;
    integer expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    task automatic tick(input bit rst);
        begin
            @(negedge clk);
            reset = rst;
            @(posedge clk);
            if (rst) expected = 0;
            else expected = (expected + 1) % 1000;
            #1;
            if (q !== expected[9:0])
                $fatal(1, "check %0d: expected %0d, got %0d", checks, expected, q);
            checks = checks + 1;
        end
    endtask

    initial begin
        // The specification does not define power-up state; establish it by reset.
        tick(1);
        tick(1);
        for (integer i = 0; i < 3005; i = i + 1) tick(0);
        // A pulse strictly between rising edges must not reset a synchronous counter.
        @(negedge clk);
        #1 reset = 1;
        #1;
        if (q !== expected[9:0]) $fatal(1, "reset acted asynchronously");
        reset = 0;
        @(posedge clk);
        expected = (expected + 1) % 1000;
        #1;
        if (q !== expected[9:0]) $fatal(1, "between-edge pulse affected count");
        checks = checks + 1;
        tick(1);
        for (integer i = 0; i < 999; i = i + 1) tick(0);
        if (q !== 10'd999) $fatal(1, "999 boundary not reached");
        tick(1); // Reset coincides with the would-be wrap edge.
        tick(1);
        for (integer i = 0; i < 1001; i = i + 1) tick(0);
        tick(1); // Reset during activity.
        tick(0);
        $display("PASS: %0d counter and synchronous-reset checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "timeout");
    end
endmodule
