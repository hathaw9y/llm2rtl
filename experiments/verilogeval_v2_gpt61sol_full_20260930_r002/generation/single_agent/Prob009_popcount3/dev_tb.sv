`timescale 1ns/1ps
module dev_tb;
    logic [2:0] in;
    wire [1:0] out;
    integer vector_value;
    integer bit_index;
    integer expected;
    integer pass_index;

    TopModule dut (.in(in), .out(out));

    initial begin
        for (pass_index = 0; pass_index < 2; pass_index = pass_index + 1) begin
            for (vector_value = 0; vector_value < 8; vector_value = vector_value + 1) begin
                if (pass_index == 0)
                    in = vector_value[2:0];
                else
                    in = 3'd7 - vector_value[2:0];
                expected = 0;
                for (bit_index = 0; bit_index < 3; bit_index = bit_index + 1) begin
                    if (in[bit_index] == 1'b1)
                        expected = expected + 1;
                end
                #1;
                if (out !== expected[1:0])
                    $fatal(1, "in=%b expected=%0d out=%b", in, expected, out);
            end
        end
        $display("PASS exhaustive population count: all 8 inputs in both orders");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
