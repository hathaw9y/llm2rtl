`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 1;
    wire [9:0] q;
    integer expected = 0;
    integer checked = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (reset) expected = 0;
        else if (expected == 999) expected = 0;
        else expected = expected + 1;
        #1;
        if (q !== expected[9:0])
            $fatal(1, "FAIL expected=%0d actual=%0d", expected, q);
        checked = checked + 1;
    end
    initial begin
        repeat (2) @(negedge clk);
        reset = 0;
        repeat (2507) @(negedge clk);
        #2;
        reset = 1;
        #1;
        if (q !== expected[9:0]) $fatal(1, "FAIL asynchronous reset effect");
        repeat (3) @(negedge clk);
        reset = 0;
        repeat (2001) @(negedge clk);
        $display("PASS: %0d checked positive edges, wraparound and synchronous reset", checked);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "FAIL timeout");
    end
endmodule
