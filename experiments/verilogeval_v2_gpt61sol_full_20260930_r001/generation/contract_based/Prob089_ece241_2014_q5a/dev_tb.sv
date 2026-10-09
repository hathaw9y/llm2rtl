`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic x = 0;
    wire z;
    integer checks = 0;
    integer width, value, i;
    logic seen;
    logic expected;
    TopModule dut(.clk(clk), .areset(areset), .x(x), .z(z));
    always #5 clk = ~clk;

    task automatic check_bit(input logic expected_bit);
        begin
            checks = checks + 1;
            if (z !== expected_bit)
                $fatal(1, "Mismatch check=%0d expected=%b actual=%b", checks, expected_bit, z);
        end
    endtask

    task automatic reset_number;
        begin
            @(negedge clk);
            #1 areset = 1;
            #1 check_bit(0);
            @(posedge clk);
            #1 check_bit(0);
            @(negedge clk);
            #1 areset = 0;
            #1 check_bit(0);
        end
    endtask

    task automatic feed(input logic bit_value, input logic expected_bit);
        logic held;
        begin
            x = bit_value;
            @(posedge clk);
            #1 check_bit(expected_bit);
            held = z;
            #1 x = ~bit_value;
            #1 check_bit(held);
            @(negedge clk);
            #1;
        end
    endtask

    task automatic test_word(input logic [31:0] word_value, input integer n);
        logic [31:0] negated;
        integer bit_index;
        begin
            reset_number();
            negated = (~word_value) + 32'd1;
            for (bit_index = 0; bit_index < n; bit_index = bit_index + 1)
                feed(word_value[bit_index], negated[bit_index]);
        end
    endtask

    initial begin
        for (width = 1; width <= 8; width = width + 1)
            for (value = 0; value < (1 << width); value = value + 1)
                test_word(value, width);
        test_word(32'h00000000, 32);
        test_word(32'h00000001, 32);
        test_word(32'h80000000, 32);
        test_word(32'hffffffff, 32);
        test_word(32'h55555555, 32);
        test_word(32'haaaaaaaa, 32);
        test_word(32'h12345678, 32);
        reset_number();
        // Arbitrary-length serial arithmetic oracle: ripple carry for ~X+1.
        seen = 0;
        for (i = 0; i < 2048; i = i + 1) begin
            if (i < 1024) x = 0;
            else if (i == 1024) x = 1;
            else x = (i % 2);
            expected = seen ? ~x : x;
            seen = seen | x;
            feed(x, expected);
        end
        // Reset interrupts an active conversion with output one.
        test_word(32'd1, 1);
        reset_number();
        feed(0, 0);
        feed(1, 1);
        feed(1, 0);
        feed(0, 1);
        $display("PASS: %0d output/reset/Moore checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Development test timeout");
    end
endmodule
