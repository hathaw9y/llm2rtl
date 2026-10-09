`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg a = 1;
    wire [2:0] q;
    integer index;
    integer expected;
    reg [2:0] table_q [0:18];
    TopModule dut (.clk(clk), .a(a), .q(q));

    task check(input reg [2:0] want);
        begin
            if (q !== want)
                $fatal(1, "At %0t expected q=%b, observed %b", $time, want, q);
        end
    endtask

    // Drive away from edges, and check both the falling and rising phases.
    task cycle(input reg level, input reg [2:0] want);
        reg [2:0] held;
        begin
            held = q;
            a = level;
            #1; check(held);
            #3.999; clk = 1;
            #0.001; check(want);
            #4.999; clk = 0;
            #0.001; check(want);
        end
    endtask

    initial begin
        table_q[0] = 3'bxxx;
        for (index = 1; index <= 10; index = index + 1)
            table_q[index] = 3'd4;
        table_q[11] = 3'd5; table_q[12] = 3'd5;
        table_q[13] = 3'd6; table_q[14] = 3'd6;
        table_q[15] = 3'd0; table_q[16] = 3'd0;
        table_q[17] = 3'd1; table_q[18] = 3'd1;
        #0.001; check(table_q[0]);
        for (index = 1; index <= 18; index = index + 1) begin
            #4.999;
            clk = ~clk;
            // Original 45 ns relationship: the old high a is sampled,
            // then a falls in NBA at the same timestamp.
            if (index == 9) a <= 0;
            #0.001; check(table_q[index]);
            if (index >= 9 && a !== 0) $fatal(1, "a did not fall at 45 ns");
        end

        // Independently enumerate the unshown states and both boundaries.
        cycle(0, 3'd2);
        cycle(0, 3'd3);
        cycle(0, 3'd4);
        cycle(0, 3'd5);
        cycle(0, 3'd6);
        cycle(0, 3'd0);
        cycle(0, 3'd1);
        cycle(1, 3'd4);
        cycle(1, 3'd4);
        cycle(0, 3'd5);
        cycle(1, 3'd4);
        cycle(0, 3'd5);
        cycle(0, 3'd6);
        cycle(1, 3'd4);
        $display("PASS: original waveform, initial unknown, load, hold, and modulo-7 boundaries");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
