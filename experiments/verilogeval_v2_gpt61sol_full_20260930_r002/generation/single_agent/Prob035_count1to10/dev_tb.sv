`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [3:0] q;
    integer expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));

    task automatic cycle(input bit rst);
        logic [3:0] previous;
        begin
            previous = q;
            reset = rst;
            #2;
            if (q !== previous)
                $fatal(1, "Output changed before rising edge");
            clk = 1;
            if (rst) expected = 1;
            else if (expected == 10) expected = 1;
            else expected = expected + 1;
            #1;
            if (q !== expected[3:0])
                $fatal(1, "Expected %0d, got %0d", expected, q);
            checks = checks + 1;
            #2;
            clk = 0;
            #1;
            if (q !== expected[3:0])
                $fatal(1, "Output changed at falling edge");
        end
    endtask

    initial begin
        // Power-up value is unspecified; first comparison follows reset.
        expected = 1;
        cycle(1);
        repeat (35) cycle(0);
        cycle(1);
        repeat (4) cycle(1);
        repeat (9) cycle(0); // Reach 10, then reset at the boundary.
        cycle(1);
        repeat (21) cycle(0);
        // A reset pulse entirely between rising edges must have no effect.
        reset = 1;
        #1;
        if (q !== expected[3:0]) $fatal(1, "Reset was asynchronous");
        reset = 0;
        #1;
        cycle(0);
        $display("PASS: %0d counter cycles and synchronous reset checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
