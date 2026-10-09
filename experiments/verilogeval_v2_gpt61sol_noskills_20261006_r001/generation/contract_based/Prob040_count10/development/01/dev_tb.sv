`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [3:0] q;
    integer expected;
    integer checks = 0;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .q(q));

    task check_value;
        begin
            if (q !== expected[3:0])
                $fatal(1, "q mismatch at %0t: expected %0d got %0d", $time, expected, q);
            checks = checks + 1;
        end
    endtask

    // Each cycle drives reset while clk is low, samples before the edge,
    // then checks the modulo-10 oracle after the sequential update.
    task cycle(input reg requested_reset);
        begin
            reset = requested_reset;
            #2;
            check_value();
            clk = 1;
            if (requested_reset)
                expected = 0;
            else
                expected = (expected + 1) % 10;
            #1;
            check_value();
            #2;
            clk = 0;
            #1;
            check_value();
        end
    endtask

    initial begin
        // No initial q assumption is specified. Establish state with reset.
        #2;
        reset = 1;
        #2;
        clk = 1;
        expected = 0;
        #1;
        check_value();
        #2;
        clk = 0;
        #1;
        check_value();
        cycle(1);
        cycle(1);
        for (i = 0; i < 35; i = i + 1)
            cycle(0);
        // Synchronous reset asserted at a nonzero value must wait for clk.
        cycle(1);
        for (i = 0; i < 9; i = i + 1)
            cycle(0);
        // Reset priority at the terminal count.
        cycle(1);
        for (i = 0; i < 30; i = i + 1)
            cycle(0);
        cycle(1);
        cycle(1);
        cycle(0);
        $display("PASS: decade counter checked with %0d comparisons", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
