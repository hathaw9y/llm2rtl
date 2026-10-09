`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic data = 0;
    wire start_shifting;
    logic [3:0] history = 0;
    logic expected = 0;
    integer count = 0;
    integer checks = 0;
    integer word_idx, bit_idx;
    TopModule dut (.clk(clk), .reset(reset), .data(data), .start_shifting(start_shifting));
    always #5 clk = ~clk;

    task automatic step(input logic rst, input logic bit_value);
        @(negedge clk);
        reset = rst;
        data = bit_value;
        @(posedge clk);
        if (rst) begin
            history = 0;
            count = 0;
            expected = 0;
        end else begin
            history = {history[2:0], bit_value};
            count = count + 1;
            if (count >= 4 && history == 4'b1101)
                expected = 1;
        end
        #1;
        checks = checks + 1;
        if (start_shifting !== expected)
            $fatal(1, "Mismatch check=%0d history=%b expected=%b actual=%b", checks, history, expected, start_shifting);
    endtask

    initial begin
        step(1, 0);
        for (word_idx = 0; word_idx < 4096; word_idx = word_idx + 1) begin
            step(1, 1);
            for (bit_idx = 11; bit_idx >= 0; bit_idx = bit_idx - 1)
                step(0, (word_idx >> bit_idx) & 1);
        end
        step(1, 0);
        step(0, 1); step(0, 1); step(0, 0); step(0, 1);
        // Reset assertion between edges must not immediately clear FOUND.
        @(negedge clk);
        reset = 1;
        #1;
        if (start_shifting !== 1'b1)
            $fatal(1, "Reset acted asynchronously");
        @(posedge clk);
        #1;
        if (start_shifting !== 1'b0)
            $fatal(1, "Synchronous reset failed");
        step(1, 0);
        step(0, 1); step(0, 1); step(1, 0); step(0, 0); step(0, 1);
        $display("PASS: %0d stream/reset comparisons, all 4096 twelve-bit streams, synchronous reset checks", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Development test timeout");
    end
endmodule
