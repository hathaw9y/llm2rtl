`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    logic out;
    TopModule dut (.a(a), .b(b), .out(out));

    task automatic check(input logic av, bv, expected);
        a = av;
        b = bv;
        #1;
        if (out !== expected)
            $fatal(1, "FAIL a=%b b=%b out=%b expected=%b", a, b, out, expected);
    endtask

    initial begin
        check(1'b0, 1'b0, 1'b0);
        check(1'b0, 1'b1, 1'b0);
        check(1'b1, 1'b0, 1'b0);
        check(1'b1, 1'b1, 1'b1);
        check(1'b1, 1'b1, 1'b1);
        check(1'b1, 1'b0, 1'b0);
        check(1'b0, 1'b1, 1'b0);
        check(1'b0, 1'b0, 1'b0);
        $display("PASS: all four AND truth-table cases, forward and reverse");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
