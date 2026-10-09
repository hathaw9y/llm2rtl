`timescale 1ns/1ps
module dev_tb;
    logic x, y;
    wire z;
    TopModule dut (.x(x), .y(y), .z(z));
    task automatic check(input logic a, input logic b, input logic expected);
        x = a;
        y = b;
        #1;
        if (z !== expected)
            $fatal(1, "FAIL: x=%b y=%b z=%b expected=%b", x, y, z, expected);
    endtask
    initial begin
        check(0, 0, 1);
        check(1, 0, 0);
        check(0, 1, 0);
        check(1, 1, 1);
        check(0, 0, 1);
        $display("PASS: all four binary input combinations and return transition");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
