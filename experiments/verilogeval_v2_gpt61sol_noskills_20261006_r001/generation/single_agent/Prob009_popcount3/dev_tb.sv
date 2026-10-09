`timescale 1ns/1ps
module dev_tb;
    reg [2:0] in;
    wire [1:0] out;
    integer value;
    integer bit_index;
    integer expected;
    integer pass_index;

    TopModule dut (.in(in), .out(out));

    initial begin
        // Exercise every input both ascending and descending to check changes.
        for (pass_index = 0; pass_index < 2; pass_index = pass_index + 1) begin
            for (value = 0; value < 8; value = value + 1) begin
                if (pass_index == 0)
                    in = value;
                else
                    in = 7 - value;
                expected = 0;
                for (bit_index = 0; bit_index < 3; bit_index = bit_index + 1)
                    if (in[bit_index] == 1'b1)
                        expected = expected + 1;
                #1;
                if (out !== expected[1:0])
                    $fatal(1, "in=%b expected=%0d out=%b", in, expected, out);
            end
        end
        $display("PASS: all eight population counts checked in both directions");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
