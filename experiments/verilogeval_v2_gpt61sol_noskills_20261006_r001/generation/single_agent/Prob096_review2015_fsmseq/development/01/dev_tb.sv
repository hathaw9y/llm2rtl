`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg data = 0;
    wire start_shifting;
    TopModule dut (.clk(clk), .reset(reset), .data(data),
                   .start_shifting(start_shifting));
    always #5 clk = ~clk;

    reg [3:0] history = 0;
    integer valid_bits = 0;
    reg expected = 0;
    integer checks = 0;
    integer pattern, bit_index;

    // Independent oracle: compare the most recent four sampled bits.
    task step(input reg rst, input reg bit_value);
        begin
            @(negedge clk);
            reset = rst;
            data = bit_value;
            #1;
            // Even an asserted reset must not change the output before a rising edge.
            if (start_shifting !== expected)
                $fatal(1, "Output changed between edges: expected %b got %b", expected, start_shifting);
            @(posedge clk);
            if (rst) begin
                history = 0;
                valid_bits = 0;
                expected = 0;
            end else begin
                history = {history[2:0], bit_value};
                if (valid_bits < 4) valid_bits = valid_bits + 1;
                if (valid_bits == 4 && history == 4'b1101) expected = 1;
            end
            #1;
            checks = checks + 1;
            if (start_shifting !== expected)
                $fatal(1, "Check %0d: history=%b reset=%b expected=%b got=%b",
                       checks, history, rst, expected, start_shifting);
        end
    endtask

    initial begin
        // No pre-reset initial value is specified; establish state with a clocked reset.
        reset = 1;
        @(posedge clk);
        #1;
        if (start_shifting !== 0) $fatal(1, "Initial synchronous reset failed");
        // Exhaust all eight-bit streams, including false prefixes and overlaps.
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            step(1, pattern[0]);
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
                step(0, (pattern >> bit_index) & 1);
            // Continue after each stream to test persistence and extended runs.
            repeat (8) step(0, 0);
        end
        // Repeated 1s retain the suffix 11, followed by immediate detection.
        step(1, 1);
        repeat (12) step(0, 1);
        step(0, 0);
        step(0, 1);
        repeat (12) step(0, 0);
        step(1, 1);
        // A reset interrupts a partial sequence; bits on reset are discarded.
        step(0, 1);
        step(0, 1);
        step(0, 0);
        step(1, 1);
        step(0, 1);
        step(0, 0);
        step(0, 1);
        step(0, 1);
        step(0, 0);
        step(0, 1);
        step(1, 0);
        step(1, 1);
        $display("PASS sequence detector: %0d sampled checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
