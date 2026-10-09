`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic shift_ena = 0, count_ena = 0, data = 0;
    wire [3:0] q;
    logic [3:0] expected;
    integer checks = 0;
    TopModule dut (.*);
    always #5 clk = ~clk;

    task automatic step(input logic shift, input logic count, input logic bit_in);
        @(negedge clk);
        shift_ena = shift;
        count_ena = count;
        data = bit_in;
        if (shift) expected = {expected[2:0], bit_in};
        else if (count) expected = expected - 4'd1;
        @(posedge clk);
        #1;
        if (q !== expected)
            $fatal(1, "Mismatch: expected=%h actual=%h", expected, q);
        checks = checks + 1;
    endtask

    initial begin
        // Flush unspecified initial state using four serial zero bits.
        repeat (4) begin
            @(negedge clk);
            shift_ena = 1;
            data = 0;
            @(posedge clk);
            #1;
        end
        expected = 0;
        if (q !== 4'd0) $fatal(1, "Initial serial load failed");
        for (integer value = 0; value < 16; value = value + 1) begin
            for (integer bit_index = 3; bit_index >= 0; bit_index = bit_index - 1)
                step(1, 0, (value >> bit_index) & 1);
            if (q !== value[3:0]) $fatal(1, "MSB-first load failed");
            step(0, 0, 0);
            step(0, 0, 1);
            repeat (17) step(0, 1, 0);
        end
        $display("PASS: %0d checked cycles, all serial values, holds, countdown and wraparound", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Testbench timeout");
    end
endmodule
