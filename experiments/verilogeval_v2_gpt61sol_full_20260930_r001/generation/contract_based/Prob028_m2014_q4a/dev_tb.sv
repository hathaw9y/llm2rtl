`timescale 1ns/1ps
module dev_tb;
    logic d, ena;
    wire q;
    integer checks = 0;
    TopModule dut (.d(d), .ena(ena), .q(q));

    task automatic check(input logic expected);
        #1;
        checks = checks + 1;
        if (q !== expected)
            $fatal(1, "FAIL check %0d: d=%b ena=%b q=%b expected=%b", checks, d, ena, q, expected);
    endtask

    initial begin
        d = 0; ena = 0;
        check(1'bx);
        d = 1; check(1'bx);
        ena = 1; check(1'b1);
        d = 0; check(1'b0);
        d = 1; check(1'b1);
        ena = 0; check(1'b1);
        d = 0; check(1'b1);
        d = 1; check(1'b1);
        d = 0; check(1'b1);
        ena = 1; check(1'b0);
        ena = 0; check(1'b0);
        d = 1; check(1'b0);
        d = 0; check(1'b0);
        repeat (8) begin
            ena = 1; d = 1; check(1'b1);
            d = 0; check(1'b0);
            ena = 0; d = 1; check(1'b0);
            ena = 1; check(1'b1);
            ena = 0; d = 0; check(1'b1);
        end
        $display("PASS: %0d latch checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
