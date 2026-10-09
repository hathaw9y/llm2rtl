`timescale 1ns/1ps
module dev_tb;
    logic [2:0] a, b;
    wire [2:0] out_or_bitwise;
    wire out_or_logical;
    wire [5:0] out_not;
    logic [2:0] expected_or;
    logic [5:0] expected_not;
    logic expected_logical;
    integer ai, bi, k;
    integer checks = 0;

    TopModule dut (.a(a), .b(b), .out_or_bitwise(out_or_bitwise),
                   .out_or_logical(out_or_logical), .out_not(out_not));

    task automatic compare_outputs(input logic [2:0] eo,
                                   input logic el,
                                   input logic [5:0] en);
        begin
            #1;
            if (out_or_bitwise !== eo || out_or_logical !== el || out_not !== en)
                $fatal(1, "a=%b b=%b got OR=%b logical=%b NOT=%b expected %b %b %b",
                       a, b, out_or_bitwise, out_or_logical, out_not, eo, el, en);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (ai = 0; ai < 8; ai = ai + 1) begin
            for (bi = 0; bi < 8; bi = bi + 1) begin
                a = ai[2:0];
                b = bi[2:0];
                for (k = 0; k < 3; k = k + 1) begin
                    case ({a[k], b[k]})
                        2'b00: expected_or[k] = 1'b0;
                        default: expected_or[k] = 1'b1;
                    endcase
                    expected_not[k] = (a[k] == 1'b0);
                    expected_not[k+3] = (b[k] == 1'b0);
                end
                expected_logical = (ai != 0) || (bi != 0);
                compare_outputs(expected_or, expected_logical, expected_not);
            end
        end
        a = 3'bxxx; b = 3'b000;
        compare_outputs(3'bxxx, 1'bx, 6'b111xxx);
        a = 3'bxxx; b = 3'b111;
        compare_outputs(3'b111, 1'b1, 6'b000xxx);
        a = 3'b000; b = 3'bzzz;
        compare_outputs(3'bxxx, 1'bx, 6'bxxx111);
        a = 3'bx01; b = 3'b000;
        compare_outputs(3'bx01, 1'b1, 6'b111x10);
        a = 3'b000; b = 3'b000;
        compare_outputs(3'b000, 1'b0, 6'b111111);
        $display("PASS: %0d combinational vector gate checks", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
