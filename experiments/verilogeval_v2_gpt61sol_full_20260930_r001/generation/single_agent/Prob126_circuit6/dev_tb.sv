`timescale 1ns/1ps
module dev_tb;
    logic [2:0] a;
    wire [15:0] q;
    logic [15:0] expected [0:7];
    integer i;
    integer pass;
    TopModule dut (.a(a), .q(q));
    initial begin
        expected[0] = 16'h1232;
        expected[1] = 16'haee0;
        expected[2] = 16'h27d4;
        expected[3] = 16'h5a0e;
        expected[4] = 16'h2066;
        expected[5] = 16'h64ce;
        expected[6] = 16'hc526;
        expected[7] = 16'h2f19;
        a = 3'bxxx;
        #1;
        if (q !== 16'hxxxx) $fatal(1, "Unknown input mismatch");
        for (pass = 0; pass < 2; pass = pass + 1) begin
            for (i = 0; i < 8; i = i + 1) begin
                a = (pass == 0) ? 3'(i) : 3'(7-i);
                #1;
                if (q !== expected[a])
                    $fatal(1, "Mismatch a=%0d q=%h expected=%h", a, q, expected[a]);
            end
        end
        $display("PASS: all eight entries checked in both orders, plus unknown input");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
