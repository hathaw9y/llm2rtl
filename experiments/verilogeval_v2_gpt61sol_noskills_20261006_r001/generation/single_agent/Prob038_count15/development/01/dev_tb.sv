`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [3:0] q;
    integer expected = 0;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    task check_value;
        input integer value;
        begin
            if (q !== value[3:0])
                $fatal(1, "time=%0t expected=%0d actual=%b", $time, value, q);
        end
    endtask

    task tick;
        begin
            @(posedge clk);
            if (reset) expected = 0;
            else expected = (expected + 1) % 16;
            #1;
            check_value(expected);
        end
    endtask

    initial begin
        // First establish a defined state with a synchronous reset.
        #2 reset = 1;
        tick;
        tick;
        @(negedge clk);
        reset = 0;
        for (i = 0; i < 35; i = i + 1) tick;

        // A reset pulse between rising edges must not change the count.
        @(negedge clk);
        #1 reset = 1;
        #1 check_value(expected);
        reset = 0;
        #1 check_value(expected);
        tick;

        // Hold reset through rising edges, then resume at one.
        @(negedge clk);
        #1 reset = 1;
        #1 check_value(expected);
        tick;
        tick;
        @(negedge clk);
        reset = 0;
        for (i = 0; i < 32; i = i + 1) tick;
        $display("PASS counter sequence, wraparound, and synchronous reset");
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
