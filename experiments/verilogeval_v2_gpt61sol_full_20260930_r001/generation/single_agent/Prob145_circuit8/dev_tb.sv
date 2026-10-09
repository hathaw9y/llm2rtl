`timescale 1ns/1ps
module dev_tb;
    logic clock, a;
    wire p, q;
    integer checks = 0;
    TopModule dut (.clock(clock), .a(a), .p(p), .q(q));
    task automatic step(input logic c, input logic d,
                        input logic expected_p, input logic expected_q);
        clock = c;
        a = d;
        #1;
        checks = checks + 1;
        if (p !== expected_p || q !== expected_q)
            $fatal(1, "check %0d: p=%b q=%b expected %b %b", checks, p, q, expected_p, expected_q);
        #4;
    endtask
    initial begin
        // Initial low clock leaves both storage elements unknown.
        step(0,0,1'bx,1'bx);
        step(1,0,0,1'bx);
        step(0,0,0,0);
        step(0,1,0,0);
        step(0,0,0,0);
        step(0,1,0,0);
        step(1,0,0,0);
        step(1,1,1,0);
        step(1,0,0,0);
        step(1,1,1,0);
        // Input changes together with the falling edge; p retains its old value.
        step(0,0,1,1);
        step(0,1,1,1);
        step(0,0,1,1);
        step(1,0,0,1);
        step(1,1,1,1);
        step(1,0,0,1);
        step(0,1,0,0);
        step(0,0,0,0);
        step(0,1,0,0);
        $display("PASS: %0d directed checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "development timeout");
    end
endmodule
