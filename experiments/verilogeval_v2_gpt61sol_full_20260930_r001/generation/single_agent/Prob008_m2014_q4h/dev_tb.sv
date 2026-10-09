`timescale 1ns/1ps
module dev_tb;
    logic in;
    wire out;
    TopModule dut (.in(in), .out(out));
    task automatic check(input logic value);
        in = value;
        #1;
        if (out !== value) $fatal(1, "FAIL: in=%b out=%b", value, out);
    endtask
    initial begin
        check(1'b0);
        check(1'b1);
        check(1'b0);
        check(1'bx);
        check(1'bz);
        check(1'b1);
        $display("PASS: combinational propagation for 0, 1, X, Z");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
