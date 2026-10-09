`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg [7:0] d = 0;
    wire [7:0] q;
    integer i;
    TopModule dut (.clk(clk), .areset(areset), .d(d), .q(q));

    task check(input [7:0] expected);
        begin
            if (q !== expected)
                $fatal(1, "q mismatch at %0t: expected %h, got %h", $time, expected, q);
        end
    endtask

    initial begin
        #10000;
        $fatal(1, "timeout");
    end

    initial begin
        // Reset between clock edges must clear the output immediately.
        #2; areset = 1;
        #1; check(8'h00);
        d = 8'hff;
        #1; clk = 1;
        #1; check(8'h00);
        clk = 0;
        #1; areset = 0;
        #1; check(8'h00);
        #1; clk = 1;
        #1; check(8'hff);
        d = 8'h55;
        #1; check(8'hff);
        clk = 0;
        #1; check(8'hff);
        // Assert reset while the clock is low and output is nonzero.
        areset = 1;
        #1; check(8'h00);
        areset = 0;
        #1; check(8'h00);
        // Exhaust all input words, checking capture and retention.
        for (i = 0; i < 256; i = i + 1) begin
            d = i;
            #1; clk = 1;
            #1; check(i);
            d = ~i;
            #1; check(i);
            clk = 0;
            #1; check(i);
        end
        d = 8'ha5;
        #1; clk = 1;
        #1; check(8'ha5);
        // Reset while the clock is high is also asynchronous.
        areset = 1;
        #1; check(8'h00);
        areset = 0;
        d = 8'h3c;
        #1; check(8'h00);
        clk = 0;
        #1; check(8'h00);
        clk = 1;
        #1; check(8'h3c);
        $display("PASS: asynchronous reset and all 256 data values checked");
        $finish;
    end
endmodule
