`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg d = 0;
    wire q;
    reg expected;
    integer i;
    TopModule dut (.clk(clk), .d(d), .q(q));

    task check(input reg value);
        begin
            if (q !== value)
                $fatal(1, "q mismatch at %0t: expected %b got %b", $time, value, q);
        end
    endtask

    task capture(input reg value);
        begin
            d = value;
            #2;
            check(expected);
            clk = 1;
            expected = value;
            #1;
            check(expected);
            // Data changes while the clock is high must not affect stored q.
            d = ~value;
            #2;
            check(expected);
            clk = 0;
            #1;
            check(expected);
            // Data changes during the low phase also must leave q unchanged.
            d = value;
            #1;
            check(expected);
        end
    endtask

    initial begin
        expected = 1'bx;
        #1;
        check(expected);
        d = 1;
        #1;
        check(expected);
        capture(0);
        capture(1);
        capture(1);
        capture(0);
        capture(0);
        for (i = 0; i < 16; i = i + 1)
            capture(i % 2);
        capture(1'bx);
        capture(0);
        capture(1'bz);
        capture(1);
        $display("PASS: positive-edge capture and between-edge hold checks");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
