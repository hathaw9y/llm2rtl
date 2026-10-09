`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    logic q;
    TopModule dut (.a(a), .b(b), .q(q));
    initial begin
        a = 0; b = 0; #1;
        if (q !== 1'b0) $fatal(1, "00 failed");
        a = 0; b = 1; #1;
        if (q !== 1'b0) $fatal(1, "01 failed");
        a = 1; b = 0; #1;
        if (q !== 1'b0) $fatal(1, "10 failed");
        a = 1; b = 1; #1;
        if (q !== 1'b1) $fatal(1, "11 failed");
        a = 0; b = 0; #1;
        if (q !== 1'b0) $fatal(1, "return to 00 failed");
        $display("PASS: all binary input combinations and return transition");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Development simulation timeout");
    end
endmodule
