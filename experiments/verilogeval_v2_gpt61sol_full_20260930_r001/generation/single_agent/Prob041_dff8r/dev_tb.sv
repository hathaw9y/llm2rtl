`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [7:0] d = 0;
    wire [7:0] q;
    logic [7:0] expected;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .d(d), .q(q));
    task automatic check(input logic [7:0] value);
        if (q !== value) $fatal(1, "FAIL q=%h expected=%h", q, value);
    endtask
    task automatic tick;
        #2; clk = 1;
        #1; expected = reset ? 8'h00 : d; check(expected);
        #2; clk = 0;
        #1; check(expected);
    endtask
    initial begin
        reset = 1; tick();
        reset = 0; d = 8'ha5; tick();
        // Reset and input changes must not change q without a rising edge.
        reset = 1; d = 8'hff; #1; check(8'ha5);
        tick();
        reset = 0; #1; check(8'h00);
        for (i = 0; i < 256; i = i + 1) begin
            d = i[7:0]; #1; check(expected); tick();
        end
        reset = 1; d = 8'hff; tick(); tick();
        reset = 0; d = 8'hff; tick();
        $display("PASS: all 256 data values, synchronous reset, reset priority, and edge/hold behavior");
        $finish;
    end
    initial begin
        #10000; $fatal(1, "FAIL timeout");
    end
endmodule
