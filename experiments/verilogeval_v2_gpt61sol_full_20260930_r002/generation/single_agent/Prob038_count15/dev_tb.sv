`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [3:0] q;
    integer expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));

    task automatic check_value(input integer value);
        begin
            if (q !== value[3:0])
                $fatal(1, "q mismatch: expected %0d got %b at %0t", value, q, $time);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input bit rst);
        begin
            reset = rst;
            #2;
            check_value(expected); // Reset changes cannot affect q without a rising edge.
            clk = 1;
            if (rst) expected = 0;
            else expected = (expected + 1) % 16;
            #1;
            check_value(expected); // Observe after nonblocking assignments settle.
            #2;
            clk = 0;
            #1;
            check_value(expected); // Falling edges cannot count.
        end
    endtask

    initial begin
        // No specified power-up value: establish the state with synchronous reset.
        #2 reset = 1;
        #2 clk = 1;
        expected = 0;
        #1 check_value(expected);
        #2 clk = 0;
        #1 check_value(expected);
        cycle(1);
        for (integer i = 0; i < 48; i = i + 1) cycle(0);
        for (integer i = 0; i < 7; i = i + 1) cycle(0);
        cycle(1);
        cycle(1);
        for (integer i = 0; i < 15; i = i + 1) cycle(0);
        cycle(1); // Reset from maximum count.
        cycle(0);
        // A reset pulse entirely between rising edges must have no effect.
        reset = 1;
        #1 check_value(expected);
        reset = 0;
        #1 check_value(expected);
        cycle(0);
        $display("PASS counter checks=%0d", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "timeout");
    end
endmodule
