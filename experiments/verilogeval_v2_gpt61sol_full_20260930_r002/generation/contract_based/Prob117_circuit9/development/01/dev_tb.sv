`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic a = 1;
    wire [2:0] q;
    integer checks = 0;
    integer i;
    TopModule dut (.clk(clk), .a(a), .q(q));

    task automatic expect_q(input logic [2:0] expected);
        begin
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "At %0t expected q=%b got %b", $time, expected, q);
        end
    endtask

    // Each table row is driven at its original integer timestamp.
    // Observe 1 ps later so sequential NBA updates have settled.
    task automatic row(input logic clock_value, input logic [2:0] expected);
        begin
            #4.999;
            clk = clock_value;
            #0.001;
            expect_q(expected);
        end
    endtask

    task automatic count_cycle(input logic [2:0] expected);
        begin
            row(1'b1, expected);
            row(1'b0, expected);
        end
    endtask

    initial begin
        #0.001;
        expect_q(3'bxxx);
        row(1, 4); // 5 ns
        row(0, 4); // 10 ns
        row(1, 4); // 15 ns
        row(0, 4); // 20 ns
        row(1, 4); // 25 ns
        row(0, 4); // 30 ns
        row(1, 4); // 35 ns
        row(0, 4); // 40 ns
        #4.999;
        clk = 1; // 45 ns: sample preceding high a
        a <= 0;  // same timestamp, after active-region sampling
        #0.001;
        expect_q(4);
        row(0, 4); // 50 ns
        row(1, 5); // 55 ns
        row(0, 5); // 60 ns
        row(1, 6); // 65 ns
        row(0, 6); // 70 ns
        row(1, 0); // 75 ns
        row(0, 0); // 80 ns
        row(1, 1); // 85 ns
        row(0, 1); // 90 ns

        // Extend the inferred sequence with literal expected values.
        count_cycle(2);
        count_cycle(3);
        count_cycle(4);
        count_cycle(5);
        count_cycle(6);
        count_cycle(0);
        count_cycle(1);
        // Change a between edges; output must remain registered.
        #1; a = 1;
        #1; expect_q(1);
        #2.999; clk = 1;
        #0.001; expect_q(4);
        row(0, 4);
        count_cycle(4);
        a = 0;
        count_cycle(5);
        count_cycle(6);
        a = 1;
        count_cycle(4);
        a = 0;
        count_cycle(5);
        count_cycle(6);
        count_cycle(0);
        a = 1;
        count_cycle(4);
        $display("PASS: original waveform and directed counter checks (%0d comparisons)", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
