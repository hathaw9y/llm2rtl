`timescale 1ns/1ps
module dev_tb;
    logic [3:0] in;
    wire out_and, out_or, out_xor;
    integer pattern, bit_index, ones, direction, checks;
    logic expected_and, expected_or, expected_xor;
    TopModule dut (.in(in), .out_and(out_and), .out_or(out_or), .out_xor(out_xor));

    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end

    initial begin
        checks = 0;
        for (direction = 0; direction < 2; direction = direction + 1) begin
            for (pattern = 0; pattern < 16; pattern = pattern + 1) begin
                if (direction == 0) in = 4'(pattern);
                else in = 4'(15 - pattern);
                ones = 0;
                for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1)
                    if (in[bit_index] == 1'b1) ones = ones + 1;
                expected_and = (ones == 4);
                expected_or = (ones != 0);
                expected_xor = ((ones % 2) == 1);
                #1;
                if ({out_and, out_or, out_xor} !== {expected_and, expected_or, expected_xor})
                    $fatal(1, "FAIL: in=%b actual=%b%b%b expected=%b%b%b", in,
                        out_and, out_or, out_xor, expected_and, expected_or, expected_xor);
                checks = checks + 1;
            end
        end
        $display("PASS: %0d checks, all 16 binary inputs in both directions", checks);
        $finish;
    end
endmodule
