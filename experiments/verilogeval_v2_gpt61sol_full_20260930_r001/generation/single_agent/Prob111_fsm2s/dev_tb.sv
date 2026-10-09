`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0, j = 0, k = 0;
    wire out;
    logic expected = 0;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .j(j), .k(k), .out(out));
    always #5 clk = ~clk;

    task automatic step(input logic r, input logic ji, input logic ki);
        @(negedge clk);
        reset = r; j = ji; k = ki;
        #1;
        if (checks > 0 && out !== expected)
            $fatal(1, "Output changed between edges");
        @(posedge clk);
        if (r) expected = 0;
        else if (expected) expected = !ki;
        else expected = ji;
        #1;
        if (out !== expected)
            $fatal(1, "Mismatch r=%b j=%b k=%b expected=%b got=%b", r, ji, ki, expected, out);
        checks = checks + 1;
    endtask

    initial begin
        step(1, 1, 1);
        for (integer s = 0; s < 2; s = s + 1) begin
            for (integer v = 0; v < 4; v = v + 1) begin
                step(1, 0, 0);
                if (s == 1) step(0, 1, 0);
                step(0, (v >> 1) & 1, v & 1);
            end
        end
        step(0, 1, 0);
        step(1, 1, 0);
        step(1, 1, 1);
        for (integer n = 0; n < 128; n = n + 1)
            step((n % 17) == 0, (n >> 1) & 1, n & 1);
        $display("PASS: %0d cycle checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Testbench timeout");
    end
endmodule
