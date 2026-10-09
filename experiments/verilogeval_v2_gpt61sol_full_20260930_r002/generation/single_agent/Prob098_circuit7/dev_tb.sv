`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic a = 1'bx;
    wire q;
    integer checks = 0;
    TopModule dut (.clk(clk), .a(a), .q(q));

    task automatic check(input logic expected);
        if (q !== expected)
            $fatal(1, "Mismatch at %0t: a=%b q=%b expected=%b", $time, a, q, expected);
        checks = checks + 1;
    endtask

    // Reach each original timestamp, preserving same-edge input changes.
    // Input changes in the inactive region, after the edge samples old a;
    // observations occur after nonblocking assignments settle.
    task automatic row(input logic clock_value, input logic input_value,
                       input logic expected);
        #4.999;
        clk = clock_value;
        #0;
        a = input_value;
        #0.001;
        check(expected);
    endtask

    initial begin
        #0.001;
        check(1'bx);
        row(1, 0, 1'bx); // 5 ns
        row(0, 0, 1'bx); // 10 ns
        row(1, 0, 1);    // 15 ns
        row(0, 0, 1);
        row(1, 0, 1);
        row(0, 0, 1);
        row(1, 1, 1);    // 35 ns: input changes at the edge
        row(0, 1, 1);
        row(1, 1, 0);    // 45 ns
        row(0, 1, 0);
        row(1, 1, 0);
        row(0, 1, 0);
        row(1, 1, 0);
        row(0, 1, 0);
        row(1, 1, 0);
        row(0, 1, 0);
        row(1, 1, 0);
        row(0, 1, 0);    // 90 ns

        // Drive away from rising edges: verify direct one-edge capture,
        // holding between edges, both transitions, and unknown propagation.
        #1 a = 0;
        #1 check(0);
        #3 clk = 1;
        #0.001 check(1);
        #1 a = 1;
        #1 check(1);
        #2.999 clk = 0;
        #5 clk = 1;
        #0.001 check(0);
        #1 a = 0;
        #3.999 clk = 0;
        #5 clk = 1;
        #0.001 check(1);
        #1 a = 1'bx;
        #1 check(1);
        #2.999 clk = 0;
        #5 clk = 1;
        #0.001 check(1'bx);
        #1 a = 1;
        #3.999 clk = 0;
        #5 clk = 1;
        #0.001 check(0);
        $display("PASS: %0d waveform and directed checks", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
