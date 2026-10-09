`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic in = 0;
    wire out;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));
    always #5 clk = ~clk;

    task automatic step(input logic r, input logic i);
        @(negedge clk);
        reset = r;
        in = i;
        #1;
        if (out !== expected) $fatal(1, "Output changed between clock edges");
        @(posedge clk);
        if (r) expected = 1;
        else if (!i) expected = ~expected;
        #1;
        if (out !== expected)
            $fatal(1, "Mismatch reset=%b in=%b expected=%b actual=%b", r, i, expected, out);
        checks = checks + 1;
    endtask

    initial begin
        reset = 1;
        @(posedge clk);
        expected = 1;
        #1;
        if (out !== expected) $fatal(1, "Initial reset failed");
        step(0, 0);
        step(0, 1);
        step(0, 0);
        step(0, 1);
        step(0, 0);
        step(1, 0);
        step(1, 1);
        for (integer pattern = 0; pattern < 256; pattern = pattern + 1) begin
            step(1, pattern[0]);
            for (integer bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1)
                step(0, pattern[bit_idx]);
        end
        $display("PASS: %0d checked cycles, all 8-bit input sequences and synchronous reset", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Testbench timeout");
    end
endmodule
