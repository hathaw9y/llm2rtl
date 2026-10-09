`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic x = 0;
    wire z;
    integer checks = 0;
    integer width, number, bit_index;
    integer expected_word;
    integer carry_bit, sum_bit;
    logic [255:0] long_word;
    TopModule dut (.clk(clk), .areset(areset), .x(x), .z(z));
    always #5 clk = ~clk;

    task automatic check_output(input logic expected_bit);
        if (z !== expected_bit)
            $fatal(1, "Mismatch t=%0t x=%b reset=%b z=%b expected=%b", $time, x, areset, z, expected_bit);
        checks = checks + 1;
    endtask

    task automatic reset_number;
        @(negedge clk);
        #1 areset = 1;
        #1 check_output(0); // Assertion is away from a clock edge.
        x = 1;
        #1 check_output(0);
        @(posedge clk);
        #1 check_output(0);
        @(negedge clk);
        #1 areset = 0;
        #1 check_output(0); // Release alone must not consume x.
    endtask

    task automatic send_bit(input logic input_bit, input logic expected_bit);
        logic held_output;
        held_output = z;
        @(negedge clk);
        x = input_bit;
        #1 check_output(held_output); // Moore output cannot follow input directly.
        @(posedge clk);
        #1 check_output(expected_bit);
    endtask

    initial begin
        // Exhaustive finite words: arithmetic negation supplies an independent oracle.
        for (width = 1; width <= 10; width = width + 1) begin
            for (number = 0; number < (1 << width); number = number + 1) begin
                reset_number();
                expected_word = (-number) & ((1 << width) - 1);
                for (bit_index = 0; bit_index < width; bit_index = bit_index + 1)
                    send_bit((number >> bit_index) & 1, (expected_word >> bit_index) & 1);
            end
        end
        // Long words exercise arbitrary-length operation and late first-one boundaries.
        for (number = 0; number < 4; number = number + 1) begin
            case (number)
                0: long_word = '0;
                1: long_word = '1;
                2: long_word = 256'b1 << 255;
                3: long_word = {8{32'h9a63c51e}};
            endcase
            reset_number();
            carry_bit = 1;
            for (bit_index = 0; bit_index < 256; bit_index = bit_index + 1) begin
                sum_bit = (1 - long_word[bit_index]) + carry_bit;
                send_bit(long_word[bit_index], sum_bit & 1);
                carry_bit = sum_bit >> 1;
            end
        end
        // Interrupt an active number and restart conversion immediately after reset.
        reset_number();
        send_bit(1, 1);
        send_bit(0, 1);
        reset_number();
        send_bit(0, 0);
        send_bit(1, 1);
        send_bit(1, 0);
        $display("PASS serial two's complement checks=%0d", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Timeout");
    end
endmodule
