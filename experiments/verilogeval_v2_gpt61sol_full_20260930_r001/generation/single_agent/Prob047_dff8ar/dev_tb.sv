`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic [7:0] d = 0;
    wire [7:0] q;
    TopModule dut (.clk(clk), .areset(areset), .d(d), .q(q));
    always #5 clk = ~clk;
    task automatic check(input logic [7:0] expected);
        if (q !== expected) $fatal(1, "FAIL expected=%h actual=%h", expected, q);
    endtask
    initial begin
        #2 areset = 1;
        #1 check(8'h00);
        d = 8'hff;
        @(posedge clk); #1 check(8'h00);
        @(negedge clk); areset = 0;
        #1 check(8'h00);
        for (int i = 0; i < 256; i++) begin
            d = i[7:0];
            @(posedge clk); #1 check(i[7:0]);
            @(negedge clk); #1 check(i[7:0]);
        end
        d = 8'h00;
        #1 check(8'hff);
        areset = 1;
        #1 check(8'h00);
        @(posedge clk); #1 check(8'h00);
        areset = 0; d = 8'ha5;
        #1 check(8'h00);
        @(posedge clk); #1 check(8'ha5);
        $display("PASS: exhaustive data capture, hold, asynchronous reset, reset priority and recovery");
        $finish;
    end
    initial begin
        #10000 $fatal(1, "FAIL timeout");
    end
endmodule
