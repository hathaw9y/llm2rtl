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

    task check_case(input integer operation, input integer lhs, input integer rhs);
        integer arithmetic;
        reg [7:0] expected;
        reg expected_zero;
        begin
            do_sub = operation;
            a = lhs;
            b = rhs;
            if (operation == 0)
                arithmetic = lhs + rhs;
            else
                arithmetic = lhs - rhs;
            expected = arithmetic & 255;
            expected_zero = (expected == 0);
            #1;
            if (out !== expected || result_is_zero !== expected_zero)
                $fatal(1, "op=%0d a=%0d b=%0d expected=%0d zero=%b got=%0d zero=%b",
                       operation, lhs, rhs, expected, expected_zero, out, result_is_zero);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_case(0, 0, 0);
        check_case(0, 1, 0);
        check_case(0, 255, 0);
        check_case(0, 255, 1);
        check_case(0, 255, 255);
        check_case(1, 0, 0);
        check_case(1, 0, 1);
        check_case(1, 255, 255);
        check_case(1, 255, 0);
        for (op = 0; op < 2; op = op + 1)
            for (av = 0; av < 256; av = av + 1)
                for (bv = 0; bv < 256; bv = bv + 1)
                    check_case(op, av, bv);
        $display("PASS exhaustive binary adder-subtractor: %0d checks", checks);
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
