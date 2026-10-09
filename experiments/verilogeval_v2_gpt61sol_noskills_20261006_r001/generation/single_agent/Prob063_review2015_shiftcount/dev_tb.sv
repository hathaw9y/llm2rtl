`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg shift_ena = 0;
    reg count_ena = 0;
    reg data = 0;
    wire [3:0] q;
    integer value, bit_index, step_index;
    integer expected;
    reg [3:0] before_edge;
    TopModule dut (.clk(clk), .shift_ena(shift_ena),
                   .count_ena(count_ena), .data(data), .q(q));

    // Drive while low; check stability before and after the falling edge.
    task cycle;
        input s;
        input c;
        input d;
        begin
            before_edge = q;
            shift_ena = s;
            count_ena = c;
            data = d;
            #4;
            if (q !== before_edge) $fatal(1, "Output changed without positive edge");
            clk = 1;
            #1;
            clk = 0;
            before_edge = q;
            #1;
            if (q !== before_edge) $fatal(1, "Output changed at falling edge");
        end
    endtask

    task check_value;
        input integer wanted;
        begin
            if (q !== wanted[3:0])
                $fatal(1, "Expected %0d, observed %b", wanted, q);
        end
    endtask

    initial begin
        // No reset or initialization is specified. Four serial bits establish
        // a known value independently of the register's initial contents.
        for (value = 0; value < 16; value = value + 1) begin
            for (bit_index = 3; bit_index >= 0; bit_index = bit_index - 1)
                cycle(1, 0, (value >> bit_index) & 1);
            expected = value;
            check_value(expected);
            cycle(0, 0, 1);
            check_value(expected);
            for (step_index = 0; step_index < 17; step_index = step_index + 1) begin
                cycle(0, 1, step_index & 1);
                expected = (expected + 15) % 16;
                check_value(expected);
                cycle(0, 0, step_index & 1);
                check_value(expected);
            end
            // Check each serial shift from a known state, including truncation.
            for (step_index = 0; step_index < 8; step_index = step_index + 1) begin
                cycle(1, 0, step_index & 1);
                expected = (expected * 2 + (step_index & 1)) % 16;
                check_value(expected);
            end
        end
        $display("PASS exhaustive loads, shifts, counts, wraparound, holds, edge timing");
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
