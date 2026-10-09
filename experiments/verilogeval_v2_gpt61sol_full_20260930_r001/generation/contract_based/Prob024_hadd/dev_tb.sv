`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire sum, cout;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .sum(sum), .cout(cout));

    task automatic check(input logic av, bv, expected_sum, expected_cout);
        a = av;
        b = bv;
        #1;
        if ({cout, sum} !== {expected_cout, expected_sum})
            $fatal(1, "FAIL a=%b b=%b sum=%b cout=%b", a, b, sum, cout);
        checks = checks + 1;
    endtask

    initial begin
        check(0, 0, 0, 0);
        check(0, 1, 1, 0);
        check(1, 0, 1, 0);
        check(1, 1, 0, 1);
        check(1, 1, 0, 1);
        check(1, 0, 1, 0);
        check(0, 1, 1, 0);
        check(0, 0, 0, 0);
        $display("PASS: %0d half-adder truth-table and repeated-input checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "FAIL watchdog timeout");
    end
endmodule
