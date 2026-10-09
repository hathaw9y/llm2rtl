`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [511:0] data = '0;
    wire [511:0] q;
    logic [511:0] expected = '0;
    logic [511:0] next_expected;
    logic [511:0] pattern;
    integer checks = 0;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;

    task automatic step(input logic do_load, input logic [511:0] value);
        @(negedge clk);
        load = do_load;
        data = value;
        if (do_load)
            next_expected = value;
        else begin
            for (integer i = 0; i < 512; i = i + 1) begin
                if (i == 0) next_expected[i] = expected[1];
                else if (i == 511) next_expected[i] = expected[510];
                else next_expected[i] = expected[i-1] ^ expected[i+1];
            end
        end
        @(posedge clk);
        #1;
        expected = next_expected;
        if (q !== expected) $fatal(1, "FAIL at check %0d", checks);
        checks = checks + 1;
        @(negedge clk);
        #1;
        if (q !== expected) $fatal(1, "FAIL: state changed without rising edge");
    endtask

    initial begin
        step(1, '0);
        repeat (5) step(0, '1);
        step(1, '1);
        repeat (10) step(0, '0);
        for (integer bit_index = 0; bit_index < 512; bit_index = bit_index + 1) begin
            pattern = '0;
            pattern[bit_index] = 1'b1;
            step(1, pattern);
            repeat (3) step(0, '0);
        end
        for (integer trial = 0; trial < 100; trial = trial + 1) begin
            for (integer word_index = 0; word_index < 16; word_index = word_index + 1)
                pattern[word_index*32 +: 32] = $urandom;
            step(1, pattern);
            repeat (10) step(0, '0);
        end
        step(1, '1);
        step(1, '0);
        $display("PASS: %0d checked cycles", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
