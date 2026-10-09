`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic d = 1'b0;
    wire q;
    logic expected;
    integer checks = 0;

    TopModule dut (.clk(clk), .d(d), .q(q));

    task automatic check_q(input logic value);
        if (q !== value)
            $fatal(1, "Mismatch at %0t: expected %b, got %b", $time, value, q);
        checks = checks + 1;
    endtask

    task automatic cycle(input logic capture_value, input logic later_value);
        // Low phase input mutation must not change the stored output.
        d = capture_value;
        #2;
        check_q(expected);
        // Capture at a positive edge, then observe after nonblocking updates.
        clk = 1'b1;
        expected = capture_value;
        #1;
        check_q(expected);
        // Input mutation while high must not propagate through a flip-flop.
        d = later_value;
        #2;
        check_q(expected);
        clk = 1'b0;
        #1;
        check_q(expected);
    endtask

    initial begin
        // No specified power-up value: establish state via the first edge.
        #2;
        clk = 1'b1;
        expected = 1'b0;
        #1;
        check_q(expected);
        d = 1'b1;
        #2;
        check_q(expected);
        clk = 1'b0;
        #1;
        check_q(expected);

        cycle(1'b1, 1'b0);
        cycle(1'b0, 1'b1);
        cycle(1'b0, 1'b1);
        cycle(1'b1, 1'b0);
        cycle(1'b1, 1'b0);
        cycle(1'bx, 1'b0);
        cycle(1'b0, 1'b1);
        cycle(1'bz, 1'b1);
        cycle(1'b1, 1'b0);
        $display("PASS: D flip-flop capture and hold verified (%0d checks)", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
