`timescale 1ns/1ps
module dev_tb;
    reg do_sub;
    reg [7:0] a, b;
    wire [7:0] out;
    wire result_is_zero;
    integer op, av, bv;
    integer checks = 0;
    TopModule dut (.do_sub(do_sub), .a(a), .b(b),
                   .out(out), .result_is_zero(result_is_zero));

    task check;
        input integer mode;
        input integer aa;
        input integer bb;
        integer expected;
        reg expected_zero;
        begin
            do_sub = mode;
            a = aa;
            b = bb;
            if (mode == 0)
                expected = (aa + bb) % 256;
            else
                expected = (aa - bb + 256) % 256;
            expected_zero = (expected == 0);
            #1;
            if (out !== expected[7:0] || result_is_zero !== expected_zero)
                $fatal(1, "mode=%0d a=%0d b=%0d out=%0d expected=%0d zero=%b expected_zero=%b",
                       mode, aa, bb, out, expected, result_is_zero, expected_zero);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(0, 0, 0);
        check(0, 0, 1);
        check(0, 255, 1);
        check(0, 255, 0);
        check(1, 255, 255);
        check(1, 0, 1);
        check(1, 0, 0);
        check(1, 1, 0);
        for (op = 0; op < 2; op = op + 1)
            for (av = 0; av < 256; av = av + 1)
                for (bv = 0; bv < 256; bv = bv + 1)
                    check(op, av, bv);
        $display("PASS exhaustive binary arithmetic and zero flag: %0d checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
