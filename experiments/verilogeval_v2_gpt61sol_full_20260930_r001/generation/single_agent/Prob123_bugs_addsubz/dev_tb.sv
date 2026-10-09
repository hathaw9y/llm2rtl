module dev_tb;
    reg do_sub;
    reg [7:0] a, b;
    wire [7:0] out;
    wire result_is_zero;
    reg [7:0] expected;
    integer op, ai, bi, checks;
    TopModule dut (.do_sub(do_sub), .a(a), .b(b), .out(out),
                   .result_is_zero(result_is_zero));
    initial begin
        checks = 0;
        for (op = 0; op < 2; op = op + 1)
            for (ai = 0; ai < 256; ai = ai + 1)
                for (bi = 0; bi < 256; bi = bi + 1) begin
                    do_sub = op;
                    a = ai;
                    b = bi;
                    if (op == 1) expected = (ai - bi) & 255;
                    else expected = (ai + bi) & 255;
                    #1;
                    if (out !== expected || result_is_zero !== (expected == 0))
                        $fatal(1, "FAIL op=%0d a=%0d b=%0d out=%0d zero=%b expected=%0d", op, ai, bi, out, result_is_zero, expected);
                    checks = checks + 1;
                end
        $display("PASS: %0d exhaustive binary-input checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
