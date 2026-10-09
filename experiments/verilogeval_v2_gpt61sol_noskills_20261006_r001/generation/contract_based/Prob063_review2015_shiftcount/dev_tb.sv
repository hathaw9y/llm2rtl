`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg shift_ena = 0;
    reg count_ena = 0;
    reg data = 0;
    wire [3:0] q;
    reg [3:0] expected = 4'bxxxx;
    integer word_value, bit_index, count_index;
    integer checks = 0;
    TopModule dut (.clk(clk), .shift_ena(shift_ena),
                   .count_ena(count_ena), .data(data), .q(q));
    always #5 clk = ~clk;

    task check_value;
        begin
            if (q !== expected)
                $fatal(1, "q mismatch: got %b expected %b at time %0t", q, expected, $time);
            checks = checks + 1;
        end
    endtask

    task cycle(input reg shift_control, input reg count_control, input reg serial_bit);
        reg [3:0] next_value;
        integer j;
        begin
            @(negedge clk);
            shift_ena = shift_control;
            count_ena = count_control;
            data = serial_bit;
            #1;
            check_value();
            next_value = expected;
            if (shift_control) begin
                for (j = 3; j > 0; j = j - 1)
                    next_value[j] = expected[j-1];
                next_value[0] = serial_bit;
            end else if (count_control)
                next_value = (expected + 15) % 16;
            #3;
            check_value();
            @(posedge clk);
            expected = next_value;
            #1;
            check_value();
        end
    endtask

    initial begin
        #1;
        check_value();
        cycle(0, 0, 1);
        // Exhaust every serial word, supplying its most significant bit first.
        for (word_value = 0; word_value < 16; word_value = word_value + 1) begin
            for (bit_index = 3; bit_index >= 0; bit_index = bit_index - 1)
                cycle(1, 0, (word_value >> bit_index) & 1);
            if (q !== word_value[3:0])
                $fatal(1, "MSB-first loading failed for %0d", word_value);
            cycle(0, 0, 0);
            cycle(0, 0, 1);
            // Traverse every value and cross zero for every starting word.
            for (count_index = 0; count_index < 17; count_index = count_index + 1)
                cycle(0, 1, count_index & 1);
            cycle(0, 0, 1);
        end
        // Interleave partial shifting, counting and holding.
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            cycle(1, 0, bit_index & 1);
            cycle(0, 1, 0);
            cycle(0, 0, 1);
        end
        $display("PASS: %0d checks, all serial words and decrement boundaries", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
