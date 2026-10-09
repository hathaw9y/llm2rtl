`timescale 1ns/1ps
module dev_tb;
    reg [3:0] in;
    wire out_and, out_or, out_xor;
    integer value;
    integer checks = 0;
    TopModule dut (.in(in), .out_and(out_and), .out_or(out_or), .out_xor(out_xor));

    task check_input(input reg [3:0] stimulus);
        integer bit_index;
        integer ones;
        reg expected_and, expected_or, expected_xor;
        begin
            ones = 0;
            for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1)
                if (stimulus[bit_index] == 1'b1) ones = ones + 1;
            expected_and = (ones == 4);
            expected_or = (ones > 0);
            expected_xor = (ones % 2 == 1);
            in = stimulus;
            #1;
            if ({out_and, out_or, out_xor} !== {expected_and, expected_or, expected_xor})
                $fatal(1, "in=%b got=%b expected=%b", in,
                       {out_and, out_or, out_xor}, {expected_and, expected_or, expected_xor});
            checks = checks + 1;
        end
    endtask

    initial begin
        for (value = 0; value < 16; value = value + 1) check_input(value[3:0]);
        for (value = 15; value >= 0; value = value - 1) check_input(value[3:0]);
        $display("PASS: %0d combinational gate checks", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
