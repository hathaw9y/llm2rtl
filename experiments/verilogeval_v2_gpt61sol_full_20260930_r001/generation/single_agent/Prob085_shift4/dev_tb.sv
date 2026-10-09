`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic load = 0;
    logic ena = 0;
    logic [3:0] data = 0;
    wire [3:0] q;
    logic [3:0] expected = 0;
    integer checks = 0;
    TopModule dut (.*);
    always #5 clk = ~clk;

    task automatic check;
        begin
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "FAIL: expected %b, got %b", expected, q);
        end
    endtask

    task automatic step(input logic l, input logic e, input logic [3:0] d);
        begin
            @(negedge clk);
            load = l;
            ena = e;
            data = d;
            #1;
            check();
            @(posedge clk);
            if (areset) expected = 0;
            else if (l) expected = d;
            else if (e) expected = expected >> 1;
            #1;
            check();
        end
    endtask

    initial begin
        #2 areset = 1;
        expected = 0;
        #1 check();
        #1 areset = 0;
        for (integer d = 0; d < 16; d = d + 1) begin
            step(1, 0, 4'(d));
            step(0, 0, 4'(~d));
            repeat (5) step(0, 1, 4'b1111);
            step(1, 1, 4'(d));
        end
        // Reset an occupied register between rising clock edges.
        step(1, 1, 4'b1111);
        @(negedge clk);
        #2 areset = 1;
        expected = 0;
        #1 check();
        @(posedge clk);
        #1 check();
        @(negedge clk);
        areset = 0;
        load = 0;
        ena = 0;
        step(0, 0, 4'b1111);
        step(1, 1, 4'b1010);
        step(0, 1, 4'b0000);
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
