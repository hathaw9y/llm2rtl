`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic data = 0;
    wire start_shifting;
    logic [3:0] history = 0;
    integer valid_bits = 0;
    logic expected = 0;
    logic initialized = 0;
    integer checks = 0;
    integer stream, bit_index;
    TopModule dut (.clk(clk), .reset(reset), .data(data), .start_shifting(start_shifting));
    always #5 clk = ~clk;

    // Independent oracle: direct comparison of the most recent four input bits.
    always @(posedge clk) begin
        if (reset) begin
            history = 0;
            valid_bits = 0;
            expected = 0;
            initialized = 1;
        end else if (initialized) begin
            history = {history[2:0], data};
            if (valid_bits < 4) valid_bits = valid_bits + 1;
            if ((valid_bits == 4) && (history == 4'b1101)) expected = 1;
        end
        #1;
        if (initialized) begin
            if (start_shifting !== expected)
                $fatal(1, "Mismatch at %0t: history=%b expected=%b actual=%b reset=%b", $time, history, expected, start_shifting, reset);
            checks = checks + 1;
        end
    end

    task automatic step(input logic reset_value, input logic data_value);
        @(negedge clk);
        reset = reset_value;
        data = data_value;
        #1;
        if (initialized && start_shifting !== expected)
            $fatal(1, "Output changed between positive edges at %0t", $time);
        @(posedge clk);
        #2;
    endtask

    initial begin
        // No assertion before the first sampled reset: initialization is unspecified.
        step(1, 1);
        for (stream = 0; stream < 256; stream = stream + 1) begin
            step(1, stream[0]);
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
                step(0, (stream >> bit_index) & 1);
            // Continue every stream to exercise sticky retention and suffix detection.
            step(0, 1); step(0, 1); step(0, 0); step(0, 1);
            step(0, 0); step(0, 0); step(0, 1);
        end
        // Reset clears partial matches, including a would-be final bit.
        step(1, 0);
        step(0, 1); step(0, 1); step(0, 0);
        step(1, 1);
        step(0, 0); step(0, 1);
        // Long run of ones must retain the two-one suffix.
        step(1, 0);
        repeat (12) step(0, 1);
        step(0, 0); step(0, 1);
        repeat (12) step(0, 0);
        // A reset pulse wholly between positive edges must not clear detection.
        @(negedge clk);
        reset = 1;
        #1;
        if (start_shifting !== 1'b1) $fatal(1, "Reset acted asynchronously");
        reset = 0;
        #1;
        if (start_shifting !== 1'b1) $fatal(1, "Inter-edge reset pulse cleared output");
        @(posedge clk); #2;
        step(1, 1);
        step(1, 0);
        step(0, 1); step(0, 1); step(0, 0); step(0, 1);
        $display("PASS: sequence detection, exhaustive streams, sticky output and synchronous reset; %0d edge checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
