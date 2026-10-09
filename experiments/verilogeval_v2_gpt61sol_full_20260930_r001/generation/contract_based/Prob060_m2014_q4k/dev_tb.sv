`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 1;
    logic in = 0;
    wire out;
    logic history [0:3];
    integer checks = 0;
    integer pattern;
    integer bit_index;
    TopModule dut (.clk(clk), .resetn(resetn), .in(in), .out(out));
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!resetn) begin
            for (integer j = 0; j < 4; j = j + 1)
                history[j] = 0;
        end else begin
            for (integer j = 3; j > 0; j = j - 1)
                history[j] = history[j-1];
            history[0] = in;
        end
        #1;
        if (out !== history[3])
            $fatal(1, "FAIL edge comparison expected=%b actual=%b", history[3], out);
        checks = checks + 1;
    end

    task automatic cycle(input logic reset_value, input logic input_value);
        @(negedge clk);
        resetn = reset_value;
        in = input_value;
        @(posedge clk);
        #2;
    endtask

    initial begin
        resetn = 0;
        cycle(0, 1);
        cycle(1, 1);
        cycle(1, 0);
        cycle(1, 0);
        cycle(1, 0);
        if (out !== 1'b1) $fatal(1, "FAIL impulse latency");
        @(negedge clk);
        resetn = 0;
        #1;
        if (out !== 1'b1) $fatal(1, "FAIL reset acted asynchronously");
        resetn = 1;
        #1;
        if (out !== 1'b1) $fatal(1, "FAIL between-edge reset pulse changed output");
        @(posedge clk);
        #2;
        repeat (5) cycle(1, 1);
        @(negedge clk);
        resetn = 0;
        #1;
        if (out !== 1'b1) $fatal(1, "FAIL reset assertion changed output before edge");
        @(posedge clk);
        #2;
        if (out !== 1'b0) $fatal(1, "FAIL synchronous clearing");
        cycle(0, 1);
        for (pattern = 0; pattern < 16; pattern = pattern + 1) begin
            cycle(0, 0);
            for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1)
                cycle(1, (pattern >> bit_index) & 1);
            repeat (4) cycle(1, 0);
        end
        for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1)
            cycle(1, bit_index % 2);
        cycle(0, 1);
        repeat (5) cycle(1, 0);
        $display("PASS: %0d checked rising edges; all input patterns, latency and synchronous reset", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL testbench timeout");
    end
endmodule
