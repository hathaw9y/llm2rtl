`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire out;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .out(out));

    task automatic check(input logic av, input logic bv, input logic expected);
        a = av;
        b = bv;
        #1;
        if (out !== expected)
            $fatal(1, "FAIL a=%b b=%b out=%b expected=%b", a, b, out, expected);
        checks = checks + 1;
    endtask

    initial begin
        check(1'b0, 1'b0, 1'b1);
        check(1'b0, 1'b1, 1'b0);
        check(1'b1, 1'b0, 1'b0);
        check(1'b1, 1'b1, 1'b1);
        check(1'b1, 1'b1, 1'b1);
        check(1'b1, 1'b0, 1'b0);
        check(1'b0, 1'b1, 1'b0);
        check(1'b0, 1'b0, 1'b1);
        $display("PASS: %0d truth-table and transition checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
