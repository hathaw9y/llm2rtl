`timescale 1ns/1ps
module dev_tb;
    reg do_sub;
    reg [7:0] a, b;
    wire [7:0] out;
    wire result_is_zero;
    integer ai, bi, mode, expected, count;
    TopModule dut (.do_sub(do_sub), .a(a), .b(b), .out(out),
                   .result_is_zero(result_is_zero));
    initial begin
        count = 0;
        for (mode = 0; mode < 2; mode = mode + 1)
            for (ai = 0; ai < 256; ai = ai + 1)
                for (bi = 0; bi < 256; bi = bi + 1) begin
                    do_sub = mode;
                    a = ai;
                    b = bi;
                    if (mode == 0) expected = (ai + bi) % 256;
                    else expected = (ai - bi + 256) % 256;
                    #1;
                    if (out !== expected[7:0] ||
                        result_is_zero !== (expected == 0))
                        $fatal(1, "FAIL mode=%0d a=%0d b=%0d out=%0d zero=%b expected=%0d",
                               mode, ai, bi, out, result_is_zero, expected);
                    count = count + 1;
                end
        $display("PASS: %0d exhaustive binary input combinations", count);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
