`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic d = 0;
    logic r = 0;
    wire q;
    TopModule dut (.clk(clk), .d(d), .r(r), .q(q));
    task automatic check(input logic expected);
        if (q !== expected)
            $fatal(1, "FAIL expected=%b actual=%b", expected, q);
    endtask
    task automatic cycle(input logic data_value, input logic reset_value);
        d = data_value;
        r = reset_value;
        #2;
        clk = 1;
        #1;
        check(reset_value ? 1'b0 : data_value);
        clk = 0;
        #1;
    endtask
    initial begin
        cycle(1, 1);
        cycle(1, 0);
        // Reset assertion between edges must not change the output.
        r = 1;
        d = 0;
        #2;
        check(1);
        clk = 1;
        #1;
        check(0);
        clk = 0;
        #1;
        cycle(0, 0);
        cycle(1, 0);
        // Changes in data between edges must not change the output.
        d = 0;
        #2;
        check(1);
        cycle(0, 0);
        cycle(0, 1);
        cycle(1, 1);
        cycle(1, 0);
        cycle(0, 0);
        $display("PASS: capture, hold, reset priority and synchronous reset");
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "FAIL testbench timeout");
    end
endmodule
