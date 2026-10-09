`timescale 1ns/1ps
module dev_tb;
    logic [7:0] a, b, c, d;
    wire [7:0] min;
    integer checks = 0;
    integer i, j;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .min(min));

    task automatic check(input logic [7:0] va, vb, vc, vd);
        integer expected;
        begin
            a = va; b = vb; c = vc; d = vd;
            // Independent oracle: scan all four unsigned values.
            expected = 255;
            if (va < expected) expected = va;
            if (vb < expected) expected = vb;
            if (vc < expected) expected = vc;
            if (vd < expected) expected = vd;
            #1;
            if (min !== expected[7:0])
                $fatal(1, "Mismatch a=%0d b=%0d c=%0d d=%0d expected=%0d actual=%0d", a,b,c,d,expected,min);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(0,0,0,0);
        check(255,255,255,255);
        check(128,127,254,255);
        check(255,254,128,127);
        for (i=0; i<256; i=i+1) begin
            check(i,i,i,i);
            check(i,255,255,255);
            check(255,i,255,255);
            check(255,255,i,255);
            check(255,255,255,i);
            check(i,i,255,255);
            check(255,255,i,i);
        end
        for (i=0; i<256; i=i+1)
            for (j=0; j<256; j=j+1) begin
                check(i,j,255,255);
                check(255,255,i,j);
            end
        for (i=0; i<10000; i=i+1)
            check($urandom, $urandom, $urandom, $urandom);
        $display("PASS unsigned minimum: %0d checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
