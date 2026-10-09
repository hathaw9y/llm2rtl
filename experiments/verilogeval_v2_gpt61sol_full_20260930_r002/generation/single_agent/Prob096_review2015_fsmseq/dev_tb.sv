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
    integer word_index, bit_index, prefix_len;
    bit initialized = 0;
    TopModule dut(.clk(clk), .reset(reset), .data(data), .start_shifting(start_shifting));
    always #5 clk = ~clk;

    task automatic step(input logic rst, input logic datum);
        @(negedge clk);
        reset = rst;
        data = datum;
        #1;
        // Neither data changes nor reset assertion may affect output before the edge.
        if (initialized && start_shifting !== expected)
            $fatal(1, "Output changed before sampling edge: expected %b got %b", expected, start_shifting);
        @(posedge clk);
        if (rst) begin
            history = 0;
            count = 0;
            expected = 0;
            initialized = 1;
        end else begin
            history = {history[2:0], datum};
            if (count < 4) count = count + 1;
            if (count >= 4 && history == 4'b1101) expected = 1;
        end
        #1;
        if (start_shifting !== expected)
            $fatal(1, "Mismatch at check %0d: reset=%b data=%b history=%b expected=%b got=%b", checks, rst, datum, history, expected, start_shifting);
        checks = checks + 1;
    endtask

    initial begin
        step(1, 1);
        // Exhaust all twelve-bit streams, including every overlap and near miss.
        for (word_index = 0; word_index < 4096; word_index = word_index + 1) begin
            step(1, word_index[0]);
            for (bit_index = 11; bit_index >= 0; bit_index = bit_index - 1)
                step(0, (word_index >> bit_index) & 1);
        end
        // Reset interrupts each nonempty prefix and also clears the sticky result.
        for (prefix_len = 1; prefix_len <= 4; prefix_len = prefix_len + 1) begin
            step(1, 0);
            step(0, 1);
            if (prefix_len >= 2) step(0, 1);
            if (prefix_len >= 3) step(0, 0);
            if (prefix_len >= 4) step(0, 1);
            step(1, 1);
            step(0, 0);
            step(0, 1);
            step(0, 0);
        end
        step(1, 0);
        step(0, 1); step(0, 1); step(0, 0); step(0, 1);
        repeat (100) begin step(0, 0); step(0, 1); end
        step(1, 1);
        step(1, 0);
        step(0, 0);
        $display("PASS: %0d checks, exhaustive streams and synchronous reset/sticky behavior", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Timeout");
    end
endmodule
