`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [1:0] ena = 0;
    logic [99:0] data = 0;
    wire [99:0] q;
    logic [99:0] expected, next_expected, pattern;
    bit initialized = 0;
    integer checks = 0;
    integer seed = 12345;
    TopModule dut (.clk(clk), .load(load), .ena(ena), .data(data), .q(q));
    always #5 clk = ~clk;
    task automatic step(input bit ld, input logic [1:0] en, input logic [99:0] value);
        @(negedge clk);
        if (initialized && q !== expected) $fatal(1, "Falling-edge mismatch");
        load = ld; ena = en; data = value;
        #1;
        if (initialized && q !== expected) $fatal(1, "Input change altered q asynchronously");
        next_expected = expected;
        if (ld) next_expected = value;
        else if (en == 2'b01)
            for (integer i = 0; i < 100; i = i + 1)
                next_expected[i] = expected[(i+1)%100];
        else if (en == 2'b10)
            for (integer i = 0; i < 100; i = i + 1)
                next_expected[i] = expected[(i+99)%100];
        @(posedge clk); #1;
        expected = next_expected;
        if (ld) initialized = 1;
        if (initialized) begin
            checks = checks + 1;
            if (q !== expected) $fatal(1, "Mismatch check %0d ena=%b load=%b expected=%h actual=%h", checks, en, ld, expected, q);
        end
    endtask
    initial begin
        for (integer en = 0; en < 4; en = en + 1) begin
            step(1, en[1:0], 100'b1);
            step(0, en[1:0], '1);
            step(1, en[1:0], '0);
            step(0, en[1:0], '1);
            step(1, en[1:0], '1);
            step(0, en[1:0], '0);
        end
        for (integer b = 0; b < 100; b = b + 1) begin
            pattern = '0; pattern[b] = 1;
            step(1, 2'b00, pattern);
            step(0, 2'b01, '0);
            step(0, 2'b10, '0);
            step(0, 2'b10, '0);
            step(0, 2'b01, '0);
        end
        pattern = 100'h123456789abcdef0123456789;
        step(1, 2'b11, pattern);
        repeat (100) step(0, 2'b01, '0);
        if (q !== pattern) $fatal(1, "Right full revolution failed");
        repeat (100) step(0, 2'b10, '0);
        if (q !== pattern) $fatal(1, "Left full revolution failed");
        for (integer n = 0; n < 1000; n = n + 1) begin
            for (integer b = 0; b < 100; b = b + 1)
                pattern[b] = ($random(seed) & 1);
            step(($random(seed) & 7) == 0, $random(seed), pattern);
        end
        $display("PASS: %0d cycle checks", checks);
        $finish;
    end
    initial begin
        #30000;
        $fatal(1, "Simulation timeout");
    end
endmodule
