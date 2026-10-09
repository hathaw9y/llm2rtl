`timescale 1ns/1ps
module dev_tb;
    reg do_sub;
    reg [7:0] a, b;
    wire [7:0] out;
    wire result_is_zero;
    integer mode, ai, bi;
    integer checks = 0;
    TopModule dut (.do_sub(do_sub), .a(a), .b(b),
                   .out(out), .result_is_zero(result_is_zero));

    task automatic check_case(input integer operation,
                              input integer lhs, input integer rhs);
        integer mathematical_result;
        reg [7:0] expected_out;
        reg expected_zero;
        begin
            do_sub = (operation == 1);
            a = lhs;
            b = rhs;
            if (operation == 1)
                mathematical_result = lhs - rhs;
            else
                mathematical_result = lhs + rhs;
            expected_out = mathematical_result & 255;
            expected_zero = (expected_out == 0);
            #1;
            if (out !== expected_out || result_is_zero !== expected_zero)
                $fatal(1, "Mismatch sub=%0d a=%0d b=%0d out=%h expected=%h zero=%b expected=%b",
                       operation, lhs, rhs, out, expected_out,
                       result_is_zero, expected_zero);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Exercise zero-to-nonzero flag transitions and arithmetic wraparound.
        check_case(0, 0, 0);
        check_case(0, 0, 1);
        check_case(0, 255, 1);
        check_case(0, 255, 0);
        check_case(1, 255, 255);
        check_case(1, 0, 1);
        check_case(1, 0, 255);
        check_case(0, 255, 255);
        // Exhaustively check every defined binary input combination.
        for (mode = 0; mode < 2; mode = mode + 1)
            for (ai = 0; ai < 256; ai = ai + 1)
                for (bi = 0; bi < 256; bi = bi + 1)
                    check_case(mode, ai, bi);
        $display("PASS: %0d combinational arithmetic and zero-flag checks", checks);
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
