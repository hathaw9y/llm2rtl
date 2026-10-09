`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [3:0] q;
    integer expected;
    integer checks = 0;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .q(q));

    task check_value;
        input integer value;
        begin
            if (q !== value[3:0])
                $fatal(1, "q mismatch: expected %0d got %b", value, q);
            checks = checks + 1;
        end
    endtask

    task tick;
        begin
            #2;
            clk = 1;
            if (reset == 1) expected = 0;
            else expected = (expected + 1) % 16;
            #1;
            check_value(expected);
            #2;
            clk = 0;
            #1;
            check_value(expected);
        end
    endtask

    initial begin
        // No power-up value is required by the original specification.
        #1;
        reset = 1;
        tick;
        reset = 0;
        #1;
        check_value(0);
        // Three complete periods exercise every value and repeated 15-to-0 wraps.
        for (i = 0; i < 48; i = i + 1) tick;
        for (i = 0; i < 7; i = i + 1) tick;
        // Assert reset while clock is low: q must remain 7 until the rising edge.
        reset = 1;
        #1;
        check_value(7);
        tick;
        tick;
        // Deassert reset during the high phase and check retention.
        clk = 1;
        #1;
        check_value(0);
        reset = 0;
        #1;
        check_value(0);
        clk = 0;
        #1;
        check_value(0);
        tick;
        // A reset pulse entirely between rising edges cannot reset the count.
        reset = 1;
        #1;
        check_value(1);
        reset = 0;
        #1;
        check_value(1);
        tick;
        for (i = 0; i < 30; i = i + 1) tick;
        $display("PASS: synchronous modulo-16 counter, %0d checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
