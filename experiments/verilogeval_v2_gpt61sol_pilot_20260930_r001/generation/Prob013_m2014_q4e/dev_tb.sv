`timescale 1ns/1ps
module dev_tb;
    logic in1, in2;
    logic out;
    TopModule dut (.in1(in1), .in2(in2), .out(out));
    task automatic check(input logic a, input logic b, input logic expected);
        in1 = a;
        in2 = b;
        #1;
        if (out !== expected)
            $fatal(1, "FAIL: in1=%b in2=%b out=%b expected=%b", a, b, out, expected);
    endtask
    initial begin
        check(1'b0, 1'b0, 1'b1);
        check(1'b0, 1'b1, 1'b0);
        check(1'b1, 1'b0, 1'b0);
        check(1'b1, 1'b1, 1'b0);
        $display("PASS: exhaustive 2-input NOR truth table (4 cases)");
        $finish;
    end
endmodule
