`timescale 1ns/1ps
module dev_tb;
    logic [3:0] in;
    wire out_and, out_or, out_xor;
    integer value, bit_index, ones;
    logic expected_and, expected_or, expected_xor;

    TopModule dut (.in(in), .out_and(out_and),
                   .out_or(out_or), .out_xor(out_xor));

    initial begin
        for (value = 0; value < 16; value = value + 1) begin
            in = value[3:0];
            ones = 0;
            for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1)
                if ((value & (1 << bit_index)) != 0)
                    ones = ones + 1;
            expected_and = (ones == 4);
            expected_or = (ones != 0);
            expected_xor = ((ones % 2) == 1);
            #1;
            if ({out_and, out_or, out_xor} !==
                {expected_and, expected_or, expected_xor})
                $fatal(1, "Mismatch in=%b actual=%b%b%b expected=%b%b%b",
                       in, out_and, out_or, out_xor,
                       expected_and, expected_or, expected_xor);
        end
        $display("PASS: all 16 four-input gate combinations checked");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
