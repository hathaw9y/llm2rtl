`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic shift_ena = 0;
    logic count_ena = 0;
    logic data = 0;
    wire [3:0] q;
    logic [3:0] expected = 4'bxxxx;
    logic [3:0] before_edge;
    integer checks = 0;
    integer value, bit_index, step;
    TopModule dut (.clk(clk), .shift_ena(shift_ena),
                   .count_ena(count_ena), .data(data), .q(q));
    always #5 clk = ~clk;

    task automatic cycle(input logic shift, input logic count, input logic serial_bit);
        begin
            @(negedge clk);
            before_edge = q;
            shift_ena = shift;
            count_ena = count;
            data = serial_bit;
            #1;
            if (q !== before_edge)
                $fatal(1, "Output changed without rising edge");
            if (shift)
                expected = (expected << 1) | {3'b000, serial_bit};
            else if (count)
                expected = expected - 4'd1;
            @(posedge clk);
            #1;
            if (q !== expected)
                $fatal(1, "check %0d: expected %b got %b", checks, expected, q);
            checks = checks + 1;
        end
    endtask

    initial begin
        // No reset or initialization is specified. Flush the unknown contents
        // with four serial bits before demanding a fully known value.
        for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1)
            cycle(1, 0, 0);
        for (value = 0; value < 16; value = value + 1) begin
            for (bit_index = 3; bit_index >= 0; bit_index = bit_index - 1)
                cycle(1, 0, (value >> bit_index) & 1);
            if (q !== value[3:0])
                $fatal(1, "MSB-first load failed for %0d", value);
            cycle(0, 0, 0);
            cycle(0, 0, 1);
            for (step = 0; step < 17; step = step + 1)
                cycle(0, 1, step[0]);
            cycle(0, 0, 1);
        end
        // Interleave shifts, counting and holds after known initialization.
        for (step = 0; step < 32; step = step + 1) begin
            cycle(1, 0, step[1]);
            cycle(0, 1, step[0]);
            cycle(0, 0, ~step[0]);
        end
        $display("PASS: %0d sequential checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Test timeout");
    end
endmodule
