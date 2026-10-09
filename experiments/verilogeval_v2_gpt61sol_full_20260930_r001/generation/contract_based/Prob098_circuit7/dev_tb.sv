`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic a = 1'bx;
    wire q;
    logic previous_sample = 1'bx;
    logic expected;
    integer checks = 0;
    integer sequence_index;
    integer bit_index;
    TopModule dut (.clk(clk), .a(a), .q(q));

    task automatic check_q(input logic value);
        begin
            checks = checks + 1;
            if (q !== value)
                $fatal(1, "Mismatch at %0t: expected %b, got %b", $time, value, q);
        end
    endtask

    task automatic cycle(input logic sample);
        begin
            a = sample;
            #4;
            check_q(expected);
            clk = 1;
            expected = ~previous_sample;
            previous_sample = sample;
            #1;
            check_q(expected);
            // Changing a after sampling must not change q.
            a = ~sample;
            #3;
            check_q(expected);
            clk = 0;
            #2;
            check_q(expected);
        end
    endtask

    initial begin
        expected = 1'bx;
        #1;
        check_q(1'bx);
        // Supplied waveform: three samples of zero then six of one.
        repeat (3) cycle(1'b0);
        repeat (6) cycle(1'b1);
        for (sequence_index = 0; sequence_index < 16; sequence_index = sequence_index + 1)
            for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1)
                cycle((sequence_index >> bit_index) & 1);
        cycle(1'bx);
        cycle(1'b0);
        cycle(1'b1);
        cycle(1'bz);
        cycle(1'b1);
        cycle(1'b0);
        $display("PASS: %0d output comparisons", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Development timeout");
    end
endmodule
