`timescale 1ns/1ps
module dev_tb;
    logic [3:0] in;
    wire out_and, out_or, out_xor;
    integer vector_value, bit_index, ones;
    integer checks = 0;
    TopModule dut (.in(in), .out_and(out_and), .out_or(out_or), .out_xor(out_xor));

    task automatic check_outputs(input logic expected_and,
                                 input logic expected_or,
                                 input logic expected_xor);
        begin
            if ({out_and, out_or, out_xor} !==
                {expected_and, expected_or, expected_xor})
                $fatal(1, "in=%b got=%b%b%b expected=%b%b%b",
                       in, out_and, out_or, out_xor,
                       expected_and, expected_or, expected_xor);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Count set bits independently of the DUT reduction expressions.
        for (vector_value = 0; vector_value < 16; vector_value = vector_value + 1) begin
            in = vector_value[3:0];
            ones = 0;
            for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1)
                if (in[bit_index] == 1'b1) ones = ones + 1;
            #1;
            check_outputs(ones == 4, ones != 0, (ones % 2) == 1);
        end
        for (vector_value = 15; vector_value >= 0; vector_value = vector_value - 1) begin
            in = vector_value[3:0];
            ones = 0;
            for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1)
                if (in[bit_index] == 1'b1) ones = ones + 1;
            #1;
            check_outputs(ones == 4, ones != 0, (ones % 2) == 1);
        end
        // Supplemental conventional four-state gate checks.
        in = 4'b000x; #1; check_outputs(1'b0, 1'bx, 1'bx);
        in = 4'b111x; #1; check_outputs(1'bx, 1'b1, 1'bx);
        in = 4'b01z0; #1; check_outputs(1'b0, 1'b1, 1'bx);
        in = 4'bzzzz; #1; check_outputs(1'bx, 1'bx, 1'bx);
        in = 4'b0000; #1; check_outputs(1'b0, 1'b0, 1'b0);
        $display("PASS: %0d combinational gate checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
