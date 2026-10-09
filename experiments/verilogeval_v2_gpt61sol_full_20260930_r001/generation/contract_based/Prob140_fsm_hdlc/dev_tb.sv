`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic in = 0;
    wire disc, flag, err;
    integer run_count = 0;
    integer checks = 0;
    integer word_idx, bit_idx, length_idx;
    logic [2:0] expected = 0;
    logic [2:0] held;
    TopModule dut (.clk(clk), .reset(reset), .in(in),
                   .disc(disc), .flag(flag), .err(err));
    always #5 clk = ~clk;

    task automatic step(input logic bit_value, input logic reset_value);
        begin
            @(negedge clk);
            held = {disc,flag,err};
            in = bit_value;
            reset = reset_value;
            #1;
            if (checks > 0 && {disc,flag,err} !== held)
                $fatal(1, "Output changed between clock edges");
            @(posedge clk);
            expected = 3'b000;
            if (reset_value) begin
                run_count = 0;
            end else if (bit_value) begin
                if (run_count < 7) run_count = run_count + 1;
                expected[0] = (run_count == 7);
            end else begin
                expected[2] = (run_count == 5);
                expected[1] = (run_count == 6);
                run_count = 0;
            end
            #1;
            checks = checks + 1;
            if ({disc,flag,err} !== expected)
                $fatal(1, "Mismatch check=%0d run=%0d in=%b reset=%b actual=%b expected=%b",
                       checks, run_count, in, reset, {disc,flag,err}, expected);
        end
    endtask

    initial begin
        step(0, 1);
        for (length_idx = 0; length_idx <= 20; length_idx = length_idx + 1) begin
            step(0, 1);
            for (bit_idx = 0; bit_idx < length_idx; bit_idx = bit_idx + 1)
                step(1, 0);
            step(0, 0);
            step(1, 0);
            step(0, 0);
        end
        // Reset from every history length and from discard/flag states.
        for (length_idx = 0; length_idx <= 9; length_idx = length_idx + 1) begin
            step(0, 1);
            for (bit_idx = 0; bit_idx < length_idx; bit_idx = bit_idx + 1)
                step(1, 0);
            step(1, 1);
            step(0, 0);
            for (bit_idx = 0; bit_idx < length_idx; bit_idx = bit_idx + 1)
                step(1, 0);
            step(0, 0);
            step(1, 1);
        end
        for (word_idx = 0; word_idx < 4096; word_idx = word_idx + 1) begin
            step(0, 1);
            for (bit_idx = 11; bit_idx >= 0; bit_idx = bit_idx - 1)
                step((word_idx >> bit_idx) & 1, 0);
            step(0, 0);
        end
        $display("PASS: %0d edge comparisons; all 4096 twelve-bit streams, directed run lengths and reset cases", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Development simulation timeout");
    end
endmodule
