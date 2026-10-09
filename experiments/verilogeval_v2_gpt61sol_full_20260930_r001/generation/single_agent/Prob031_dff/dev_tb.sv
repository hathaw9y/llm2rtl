`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic d = 0;
    wire q;
    TopModule dut (.clk(clk), .d(d), .q(q));
    task automatic cycle(input logic value);
        d = value;
        #2;
        clk = 1;
        #1;
        if (q !== value) $fatal(1, "Rising edge capture failed");
        d = ~value;
        #1;
        if (q !== value) $fatal(1, "Output changed between edges");
        clk = 0;
        #1;
        if (q !== value) $fatal(1, "Output changed at falling edge");
        #1;
    endtask
    initial begin
        cycle(0);
        cycle(1);
        cycle(1);
        cycle(0);
        cycle(0);
        cycle(1);
        $display("PASS: rising-edge capture and output hold");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Test timeout");
    end
endmodule
