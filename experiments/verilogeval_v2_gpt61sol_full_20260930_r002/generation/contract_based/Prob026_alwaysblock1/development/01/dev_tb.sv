`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire out_assign, out_alwaysblock;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .out_assign(out_assign),
                   .out_alwaysblock(out_alwaysblock));

    task automatic check(input logic av, input logic bv, input logic expected);
        a = av;
        b = bv;
        #1;
        if (out_assign !== expected || out_alwaysblock !== expected)
            $fatal(1, "a=%b b=%b expected=%b assign=%b always=%b",
                   a, b, expected, out_assign, out_alwaysblock);
        checks = checks + 1;
    endtask

    initial begin
        // Explicit original AND truth table, with both input transition directions.
        check(1'b0, 1'b0, 1'b0);
        check(1'b0, 1'b1, 1'b0);
        check(1'b1, 1'b1, 1'b1);
        check(1'b1, 1'b0, 1'b0);
        check(1'b1, 1'b1, 1'b1);
        check(1'b0, 1'b1, 1'b0);
        check(1'b0, 1'b0, 1'b0);
        check(1'b1, 1'b0, 1'b0);
        // Supplemental standard four-state AND semantics.
        check(1'b0, 1'bx, 1'b0);
        check(1'bx, 1'b0, 1'b0);
        check(1'b0, 1'bz, 1'b0);
        check(1'bz, 1'b0, 1'b0);
        check(1'b1, 1'bx, 1'bx);
        check(1'bx, 1'b1, 1'bx);
        check(1'b1, 1'bz, 1'bx);
        check(1'bz, 1'b1, 1'bx);
        check(1'bx, 1'bx, 1'bx);
        check(1'bx, 1'bz, 1'bx);
        check(1'bz, 1'bx, 1'bx);
        check(1'bz, 1'bz, 1'bx);
        check(1'b1, 1'b1, 1'b1);
        $display("PASS %0d AND gate checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
