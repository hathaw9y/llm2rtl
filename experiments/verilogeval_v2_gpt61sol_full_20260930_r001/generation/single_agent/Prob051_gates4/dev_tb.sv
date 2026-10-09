`timescale 1ns/1ps
module dev_tb;
    logic [3:0] in;
    logic out_and, out_or, out_xor;
    integer value;
    integer bit_index;
    integer ones;
    logic expected_and, expected_or, expected_xor;
    TopModule dut (.in(in), .out_and(out_and), .out_or(out_or), .out_xor(out_xor));
    initial begin
        for (value = 0; value < 16; value = value + 1) begin
            in = 4'(value);
            ones = 0;
            for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1)
                if (in[bit_index]) ones = ones + 1;
            expected_and = (ones == 4);
            expected_or = (ones != 0);
            expected_xor = ((ones % 2) == 1);
            #1;
            if ({out_and, out_or, out_xor} !== {expected_and, expected_or, expected_xor})
                $fatal(1, "FAIL input=%b outputs=%b%b%b", in, out_and, out_or, out_xor);
        end
        $display("PASS: all 16 binary input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
