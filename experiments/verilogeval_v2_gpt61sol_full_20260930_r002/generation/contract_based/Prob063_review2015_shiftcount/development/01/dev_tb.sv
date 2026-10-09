`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic shift_ena = 0;
    logic count_ena = 0;
    logic data = 0;
    wire [3:0] q;
    logic [3:0] expected;
    logic [3:0] before_edge;
    integer checks = 0;
    integer word_value, bit_index, count_index;
    integer serial_value;

    TopModule dut (.clk(clk), .shift_ena(shift_ena),
                   .count_ena(count_ena), .data(data), .q(q));
    always #5 clk = ~clk;

    task automatic step(input logic shift_on, input logic count_on,
                        input logic serial_bit, input logic [3:0] want);
        begin
            @(negedge clk);
            before_edge = q;
            shift_ena = shift_on;
            count_ena = count_on;
            data = serial_bit;
            #1;
            if (q !== before_edge)
                $fatal(1, "Output changed on falling edge or input change");
            #3;
            if (q !== before_edge)
                $fatal(1, "Output changed before rising edge");
            @(posedge clk);
            #1;
            if (q !== want)
                $fatal(1, "Check %0d: got %b expected %b", checks, q, want);
            checks = checks + 1;
        end
    endtask

    initial begin
        #1;
        // No reset or initialization was specified: no initial value is added.
        if (q !== 4'bxxxx) $fatal(1, "Unexpected initialized register");
        expected = 4'bxxxx;
        step(0, 0, 1, expected);
        // Explicit partial loading checks also establish serial direction.
        step(1, 0, 1, 4'bxxx1);
        step(1, 0, 0, 4'bxx10);
        step(1, 0, 1, 4'bx101);
        step(1, 0, 1, 4'b1011);
        expected = 4'd11;
        step(0, 0, 0, expected);
        step(0, 1, 1, 4'd10);
        expected = 4'd10;
        // Exhaustive MSB-first word loads, each checked at every bit.
        for (word_value = 0; word_value < 16; word_value = word_value + 1) begin
            for (bit_index = 3; bit_index >= 0; bit_index = bit_index - 1) begin
                serial_value = (word_value >> bit_index) & 1;
                expected = ((expected * 2) + serial_value) % 16;
                step(1, 0, serial_value != 0, expected);
            end
            if (q !== word_value[3:0])
                $fatal(1, "MSB-first word load mismatch for %0d", word_value);
            step(0, 0, 0, expected);
            step(0, 0, 1, expected);
            // More than two complete count cycles, including 0 -> 15.
            for (count_index = 0; count_index < 33; count_index = count_index + 1) begin
                expected = (int'(expected) + 15) % 16;
                step(0, 1, count_index[0], expected);
                if ((count_index % 7) == 0)
                    step(0, 0, !count_index[0], expected);
            end
        end
        // Alternate serial shifts and counting without a four-bit reload.
        for (count_index = 0; count_index < 32; count_index = count_index + 1) begin
            serial_value = ((count_index * 5 + 3) >> 1) & 1;
            expected = ((expected * 2) + serial_value) % 16;
            step(1, 0, serial_value != 0, expected);
            expected = (int'(expected) + 15) % 16;
            step(0, 1, 0, expected);
        end
        $display("PASS %0d checks: serial loading, hold, edge behavior, decrement and wraparound", checks);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Bounded timeout");
    end
endmodule
