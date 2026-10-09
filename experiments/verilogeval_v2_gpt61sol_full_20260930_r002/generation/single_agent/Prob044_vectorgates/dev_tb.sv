`timescale 1ns/1ps
module dev_tb;
    logic [2:0] a, b;
    wire [2:0] out_or_bitwise;
    wire out_or_logical;
    wire [5:0] out_not;
    logic [2:0] expected_or;
    logic [5:0] expected_not;
    logic expected_logical;
    integer ai, bi, bit_index;

    TopModule dut (.a(a), .b(b), .out_or_bitwise(out_or_bitwise),
                   .out_or_logical(out_or_logical), .out_not(out_not));

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end

    initial begin
        for (ai = 0; ai < 8; ai = ai + 1) begin
            for (bi = 0; bi < 8; bi = bi + 1) begin
                a = ai[2:0];
                b = bi[2:0];
                expected_logical = (ai != 0) || (bi != 0);
                for (bit_index = 0; bit_index < 3; bit_index = bit_index + 1) begin
                    expected_or[bit_index] = (a[bit_index] == 1'b1) ||
                                             (b[bit_index] == 1'b1);
                    expected_not[bit_index] = (a[bit_index] == 1'b0);
                    expected_not[bit_index + 3] = (b[bit_index] == 1'b0);
                end
                #1;
                if (out_or_bitwise !== expected_or ||
                    out_or_logical !== expected_logical ||
                    out_not !== expected_not)
                    $fatal(1, "Mismatch a=%b b=%b OR=%b logical=%b NOT=%b", 
                           a, b, out_or_bitwise, out_or_logical, out_not);
            end
        end
        $display("PASS: all 64 input combinations checked");
        $finish;
    end
endmodule
