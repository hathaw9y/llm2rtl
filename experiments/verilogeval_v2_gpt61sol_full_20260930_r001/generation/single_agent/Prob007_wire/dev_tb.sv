`timescale 1ns/1ps
module dev_tb;
    logic in;
    logic out;
    TopModule dut (.in(in), .out(out));
    task automatic check(input logic value);
        in = value;
        #1;
        if (out !== value) $fatal(1, "FAIL: input=%b output=%b", value, out);
    endtask
    initial begin
        check(1'b0);
        check(1'b1);
        check(1'b0);
        check(1'bx);
        check(1'bz);
        check(1'b1);
        $display("PASS: wire propagates 0, 1, X, Z and repeated transitions");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: development timeout");
    end
endmodule
