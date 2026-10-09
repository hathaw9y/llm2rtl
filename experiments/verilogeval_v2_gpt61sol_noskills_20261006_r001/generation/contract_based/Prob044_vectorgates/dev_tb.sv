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

    task check_outputs;
        input [2:0] want_or;
        input want_logical;
        input [5:0] want_not;
        begin
            #1;
            if (out_or_bitwise !== want_or ||
                out_or_logical !== want_logical || out_not !== want_not)
                $fatal(1, "a=%b b=%b: got OR=%b logical=%b NOT=%b; expected %b %b %b",
                    a, b, out_or_bitwise, out_or_logical, out_not,
                    want_or, want_logical, want_not);
        end
    endtask

    initial begin
        for (av = 0; av < 8; av = av + 1) begin
            for (bv = 0; bv < 8; bv = bv + 1) begin
                a = av;
                b = bv;
                for (bit_index = 0; bit_index < 3; bit_index = bit_index + 1) begin
                    case ({a[bit_index], b[bit_index]})
                        2'b00: expected_or[bit_index] = 0;
                        default: expected_or[bit_index] = 1;
                    endcase
                    if (a[bit_index] == 0) expected_not[bit_index] = 1;
                    else expected_not[bit_index] = 0;
                    if (b[bit_index] == 0) expected_not[bit_index+3] = 1;
                    else expected_not[bit_index+3] = 0;
                end
                expected_logical = (av != 0) || (bv != 0);
                check_outputs(expected_or, expected_logical, expected_not);
            end
        end
        a = 3'bx00; b = 3'b000;
        check_outputs(3'bx00, 1'bx, 6'b111x11);
        a = 3'bx00; b = 3'b100;
        check_outputs(3'b100, 1'b1, 6'b011x11);
        a = 3'b000; b = 3'b0z0;
        check_outputs(3'b0x0, 1'bx, 6'b1x1111);
        a = 3'b001; b = 3'bzzz;
        check_outputs(3'bxx1, 1'b1, 6'bxxx110);
        $display("PASS: all 64 binary input pairs and 4 directed four-state cases");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Development test timeout");
    end
endmodule
