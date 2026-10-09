`timescale 1ns/1ps
module dev_tb;
    logic a;
    logic b;
    wire out;
    integer checks = 0;

    TopModule dut (.a(a), .b(b), .out(out));

    // Expected values come from the original two-input AND truth table.
    task automatic check_case(input logic av, input logic bv, input logic expected);
        a = av;
        b = bv;
        #1;
        if (out !== expected)
            $fatal(1, "AND mismatch: a=%b b=%b expected=%b actual=%b", a, b, expected, out);
        checks = checks + 1;
    endtask

    initial begin
        check_case(1'b0, 1'b0, 1'b0);
        check_case(1'b0, 1'b1, 1'b0);
        check_case(1'b1, 1'b1, 1'b1);
        check_case(1'b1, 1'b0, 1'b0);
        check_case(1'b1, 1'b1, 1'b1);
        check_case(1'b0, 1'b1, 1'b0);
        check_case(1'b1, 1'b1, 1'b1);
        check_case(1'b0, 1'b0, 1'b0);
        $display("PASS: %0d original AND truth-table and transition checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout checking combinational AND gate");
    end
endmodule
