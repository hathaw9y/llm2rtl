`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic [7:0] d = 0;
    wire [7:0] q;
    integer checks = 0;
    TopModule dut (.clk(clk), .areset(areset), .d(d), .q(q));

    task automatic check(input logic [7:0] expected);
        begin
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "FAIL check=%0d q=%h expected=%h", checks, q, expected);
        end
    endtask

    initial begin
        #1; d = 8'hff; areset = 1;
        #1; check(8'h00);
        clk = 1;
        #1; check(8'h00);
        clk = 0; areset = 0;
        #1; check(8'h00);
        for (integer value = 0; value < 256; value = value + 1) begin
            d = value[7:0];
            #1; clk = 1;
            #1; check(value[7:0]);
            d = ~value[7:0];
            #1; check(value[7:0]);
            clk = 0;
            #1; check(value[7:0]);
        end
        // Last captured value is FF; assert reset while clock stays low.
        areset = 1;
        #1; check(8'h00);
        d = 8'ha5;
        clk = 1;
        #1; check(8'h00);
        areset = 0;
        #1; check(8'h00);
        clk = 0;
        #1; check(8'h00);
        clk = 1;
        #1; check(8'ha5);
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "FAIL: development watchdog timeout");
    end
endmodule
