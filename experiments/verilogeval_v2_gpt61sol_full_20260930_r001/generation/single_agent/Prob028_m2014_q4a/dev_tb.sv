`timescale 1ns/1ps
module dev_tb;
    logic d = 0;
    logic ena = 0;
    wire q;
    TopModule dut (.d(d), .ena(ena), .q(q));

    task automatic check(input logic expected);
        #1;
        if (q !== expected)
            $fatal(1, "FAIL: d=%b ena=%b q=%b expected=%b", d, ena, q, expected);
    endtask

    initial begin
        #1;
        ena = 1;
        check(0);
        d = 1;
        check(1);
        d = 0;
        check(0);
        ena = 0;
        d = 1;
        check(0);
        d = 0;
        check(0);
        d = 1;
        ena = 1;
        check(1);
        ena = 0;
        d = 0;
        check(1);
        d = 1;
        check(1);
        ena = 1;
        check(1);
        d = 0;
        check(0);
        $display("PASS: latch transparency and retention");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
