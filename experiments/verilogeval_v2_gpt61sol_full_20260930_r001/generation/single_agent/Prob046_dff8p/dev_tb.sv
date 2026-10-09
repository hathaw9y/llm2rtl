`timescale 1ns/1ps
module dev_tb;
    logic clk = 1;
    logic reset = 0;
    logic [7:0] d = 0;
    wire [7:0] q;
    logic [7:0] expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .d(d), .q(q));

    task automatic check(input logic [7:0] value);
        begin
            checks = checks + 1;
            if (q !== value)
                $fatal(1, "FAIL check %0d: q=%h expected=%h", checks, q, value);
        end
    endtask

    initial begin
        #1; clk = 0; #1; expected = 0; check(expected);
        for (integer i = 0; i < 256; i = i + 1) begin
            clk = 1; #1; check(expected);
            d = i; reset = (i % 7 == 0);
            #1; check(expected);
            clk = 0;
            expected = reset ? 8'h34 : d;
            #1; check(expected);
            reset = ~reset; d = ~d;
            #1; check(expected);
        end
        $display("PASS: %0d checks; falling-edge capture, synchronous reset, reset priority, and output hold", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
