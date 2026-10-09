`timescale 1ns/1ps
module dev_tb;
    reg [2:0] a, b;
    wire [2:0] out_or_bitwise;
    wire out_or_logical;
    wire [5:0] out_not;
    reg [2:0] expected_or;
    reg [5:0] expected_not;
    reg expected_logical;
    integer av, bv, bit_index;

    TopModule dut (.a(a), .b(b), .out_or_bitwise(out_or_bitwise),
        .out_or_logical(out_or_logical), .out_not(out_not));

    initial begin
        for (av = 0; av < 8; av = av + 1) begin
            for (bv = 0; bv < 8; bv = bv + 1) begin
                a = av;
                b = bv;
                for (bit_index = 0; bit_index < 3; bit_index = bit_index + 1) begin
                    expected_or[bit_index] = ((av >> bit_index) % 2 == 1) ||
                                             ((bv >> bit_index) % 2 == 1);
                    expected_not[bit_index] = ((av >> bit_index) % 2 == 0);
                    expected_not[bit_index + 3] = ((bv >> bit_index) % 2 == 0);
                end
                expected_logical = (av != 0) || (bv != 0);
                #1;
                if (out_or_bitwise !== expected_or ||
                    out_or_logical !== expected_logical ||
                    out_not !== expected_not)
                    $fatal(1, "Mismatch a=%b b=%b: OR=%b logical=%b NOT=%b", a, b,
                           out_or_bitwise, out_or_logical, out_not);
            end
        end
        $display("PASS exhaustive 64 input combinations");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
