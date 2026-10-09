`timescale 1ns/1ps
module dev_tb;
    logic [2:0] a, b;
    wire [2:0] out_or_bitwise;
    wire out_or_logical;
    wire [5:0] out_not;
    logic [2:0] expected_or;
    logic expected_logical;
    logic [5:0] expected_not;
    integer av, bv, bit_index;
    TopModule dut (.a(a), .b(b), .out_or_bitwise(out_or_bitwise),
                   .out_or_logical(out_or_logical), .out_not(out_not));
    initial begin
        for (av = 0; av < 8; av = av + 1) begin
            for (bv = 0; bv < 8; bv = bv + 1) begin
                a = av[2:0];
                b = bv[2:0];
                expected_logical = 1'b0;
                for (bit_index = 0; bit_index < 3; bit_index = bit_index + 1) begin
                    case ({a[bit_index], b[bit_index]})
                        2'b00: expected_or[bit_index] = 1'b0;
                        default: expected_or[bit_index] = 1'b1;
                    endcase
                    if (a[bit_index] == 1'b1 || b[bit_index] == 1'b1)
                        expected_logical = 1'b1;
                    expected_not[bit_index] = (a[bit_index] == 1'b0) ? 1'b1 : 1'b0;
                    expected_not[bit_index+3] = (b[bit_index] == 1'b0) ? 1'b1 : 1'b0;
                end
                #1;
                if (out_or_bitwise !== expected_or ||
                    out_or_logical !== expected_logical || out_not !== expected_not)
                    $fatal(1, "FAIL a=%b b=%b OR=%b logical=%b NOT=%b", a, b,
                           out_or_bitwise, out_or_logical, out_not);
            end
        end
        $display("PASS: all 64 binary input pairs");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
