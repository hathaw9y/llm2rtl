`timescale 1ns/1ps
module dev_tb;
    logic [7:0] a, b, c, d;
    wire [7:0] min;
    integer checks = 0;
    integer i, j, lane;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .min(min));

    task automatic check(input logic [7:0] av, bv, cv, dv);
        integer expected;
        begin
            a = av; b = bv; c = cv; d = dv;
            expected = av;
            if (bv < expected) expected = bv;
            if (cv < expected) expected = cv;
            if (dv < expected) expected = dv;
            #1;
            if (min !== expected[7:0])
                $fatal(1, "FAIL a=%0d b=%0d c=%0d d=%0d min=%0d expected=%0d", a,b,c,d,min,expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(0,0,0,0);
        check(255,255,255,255);
        check(128,127,254,255);
        check(255,254,253,128);
        for (i = 0; i < 256; i = i + 1) begin
            check(i,i,i,i);
            for (lane = 0; lane < 4; lane = lane + 1) begin
                case (lane)
                    0: check(i,255,255,255);
                    1: check(255,i,255,255);
                    2: check(255,255,i,255);
                    3: check(255,255,255,i);
                endcase
            end
            for (j = 0; j < 256; j = j + 1) begin
                check(i,j,255,255);
                check(255,255,i,j);
            end
        end
        for (i = 0; i < 10000; i = i + 1)
            check($urandom, $urandom, $urandom, $urandom);
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
