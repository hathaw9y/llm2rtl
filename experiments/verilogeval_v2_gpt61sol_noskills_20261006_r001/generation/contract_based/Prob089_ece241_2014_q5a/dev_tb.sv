`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg x = 0;
    wire z;
    reg held;
    reg [127:0] word_value, negated;
    integer n, value, bit_index, checks = 0;
    TopModule dut (.clk(clk), .areset(areset), .x(x), .z(z));

    task check_output(input reg expected);
        begin
            if (z !== expected)
                $fatal(1, "Output mismatch at time %0t: expected %b got %b", $time, expected, z);
            checks = checks + 1;
        end
    endtask

    task reset_conversion;
        begin
            // All callers leave clk low. Assert asynchronously between edges.
            #2; areset = 1;
            #1; check_output(0);
            x = ~x;
            #1; check_output(0);
            clk = 1;
            #1; check_output(0);
            clk = 0;
            #1; areset = 0;
            #1; check_output(0);
        end
    endtask

    task consume(input reg input_bit, input reg expected_bit);
        begin
            held = z;
            x = input_bit;
            #2; check_output(held); // Moore output cannot follow x between edges.
            clk = 1;
            #1; check_output(expected_bit);
            x = ~input_bit;
            #1; check_output(expected_bit);
            clk = 0;
            #1; check_output(expected_bit);
        end
    endtask

    task test_word(input reg [127:0] bits, input integer length);
        reg [127:0] complement_word;
        integer i;
        begin
            reset_conversion;
            // Independent arithmetic oracle: two's complement modulo 2^length.
            complement_word = (~bits) + 128'd1;
            for (i = 0; i < length; i = i + 1)
                consume(bits[i], complement_word[i]);
        end
    endtask

    initial begin
        // Do not constrain the unspecified power-up state before reset.
        reset_conversion;
        for (n = 1; n <= 8; n = n + 1)
            for (value = 0; value < (1 << n); value = value + 1)
                test_word(value, n);
        test_word(128'd0, 128);
        test_word({128{1'b1}}, 128);
        test_word(128'd1, 128);
        test_word(128'h80000000000000000000000000000000, 128);
        test_word({64{2'b10}}, 128);
        test_word({64{2'b01}}, 128);
        // Reset interrupts an active number, then immediately starts a fresh one.
        reset_conversion;
        consume(1, 1);
        consume(0, 1);
        consume(1, 0);
        reset_conversion;
        consume(0, 0);
        consume(0, 0);
        consume(1, 1);
        consume(1, 0);
        consume(0, 1);
        $display("PASS serial complement development checks: %0d comparisons", checks);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Development timeout");
    end
endmodule
