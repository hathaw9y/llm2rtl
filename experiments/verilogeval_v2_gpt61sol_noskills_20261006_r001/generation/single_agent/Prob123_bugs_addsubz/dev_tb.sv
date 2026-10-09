`timescale 1ns/1ps
module dev_tb;
    reg do_sub;
    reg [7:0] a, b;
    wire [7:0] out;
    wire result_is_zero;
    integer op, ai, bi;
    integer checks = 0;
    TopModule dut (.do_sub(do_sub), .a(a), .b(b),
                   .out(out), .result_is_zero(result_is_zero));

    task check_result;
        input integer operation;
        input integer lhs;
        input integer rhs;
        integer expected;
        begin
            do_sub = operation;
            a = lhs;
            b = rhs;
            // The specified output is the low eight bits of the arithmetic result.
            if (operation == 1) expected = (lhs - rhs) & 255;
            else expected = (lhs + rhs) & 255;
            #1;
            if (out !== expected[7:0])
                $fatal(1, "Arithmetic mismatch: sub=%0d a=%0d b=%0d out=%0d expected=%0d",
                       operation, lhs, rhs, out, expected);
            if (result_is_zero !== (expected == 0))
                $fatal(1, "Zero flag mismatch: sub=%0d a=%0d b=%0d result=%0d flag=%b",
                       operation, lhs, rhs, expected, result_is_zero);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Directed transitions expose stale flags and truncated arithmetic boundaries.
        check_result(0, 0, 0);
        check_result(0, 0, 1);
        check_result(0, 255, 1);
        check_result(0, 255, 0);
        check_result(1, 255, 255);
        check_result(1, 0, 1);
        check_result(1, 1, 0);
        check_result(0, 128, 128);
        for (op = 0; op < 2; op = op + 1)
            for (ai = 0; ai < 256; ai = ai + 1)
                for (bi = 0; bi < 256; bi = bi + 1)
                    check_result(op, ai, bi);
        $display("PASS: %0d arithmetic and zero-flag checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
