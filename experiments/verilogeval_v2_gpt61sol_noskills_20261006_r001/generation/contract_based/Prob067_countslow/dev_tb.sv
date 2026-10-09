`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg slowena = 0;
    wire [3:0] q;
    integer expected = 0;
    integer checks = 0;
    integer i;
    reg initialized = 0;
    reg [3:0] prior;
    TopModule dut (.clk(clk), .reset(reset), .slowena(slowena), .q(q));

    // Each call starts with clk low, changes inputs away from the rising
    // edge, then checks the original synchronous transition rule.
    task cycle(input reg rst, input reg ena);
        begin
            prior = q;
            reset = rst;
            slowena = ena;
            #3;
            if (initialized && q !== prior)
                $fatal(1, "Output changed without rising edge: prior=%h q=%h", prior, q);
            clk = 1;
            if (rst) begin
                expected = 0;
                initialized = 1;
            end else if (initialized && ena) begin
                expected = (expected + 1) % 10;
            end
            #1;
            if (initialized) begin
                if (q !== expected[3:0])
                    $fatal(1, "Mismatch check=%0d reset=%b enable=%b expected=%0d q=%h", checks, rst, ena, expected, q);
                checks = checks + 1;
            end
            #2;
            clk = 0;
            #1;
            if (initialized && q !== expected[3:0])
                $fatal(1, "Count changed on falling edge");
        end
    endtask

    initial begin
        // No assumption is made about q before reset: unspecified by problem.
        cycle(1, 0);
        repeat (4) cycle(0, 0);
        repeat (9) cycle(0, 1);
        repeat (5) cycle(0, 0); // Hold at nine.
        cycle(0, 1);           // Rollover to zero.
        repeat (30) cycle(0, 1);
        repeat (6) cycle(0, 1);
        cycle(1, 0);           // Reset from nonzero with enable low.
        repeat (7) cycle(0, 1);
        cycle(1, 1);           // Reset takes priority over enable.
        repeat (3) cycle(1, 1);
        cycle(0, 0);
        for (i = 0; i < 200; i = i + 1)
            cycle((i % 31) == 17, ((i % 7) < 4));
        $display("PASS: %0d synchronous decade-counter checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
