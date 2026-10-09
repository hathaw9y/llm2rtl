`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [511:0] data = '0;
    wire [511:0] q;
    logic [511:0] expected = 'x;
    logic [511:0] pattern;
    logic [31:0] rng = 32'h917ac4e3;
    integer checks = 0;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;

    function automatic [511:0] rule90(input logic [511:0] old_state);
        integer i;
        logic left_cell, right_cell;
        begin
            for (i = 0; i < 512; i = i + 1) begin
                if (i == 0) left_cell = 1'b0;
                else left_cell = old_state[i-1];
                if (i == 511) right_cell = 1'b0;
                else right_cell = old_state[i+1];
                rule90[i] = left_cell ^ right_cell;
            end
        end
    endfunction

    task automatic compare_state;
        begin
            if (q !== expected)
                $fatal(1, "State mismatch check=%0d time=%0t actual=%h expected=%h", checks, $time, q, expected);
            checks = checks + 1;
        end
    endtask

    task automatic step(input logic do_load, input logic [511:0] payload);
        begin
            @(negedge clk);
            load = do_load;
            data = payload;
            #1;
            compare_state(); // Falling edges and input mutation must not change q.
            @(posedge clk);
            if (do_load) expected = payload;
            else expected = rule90(expected);
            #1;
            compare_state();
        end
    endtask

    initial begin
        #1;
        compare_state(); // No initialization in the specified resetless design.
        step(0, '0);
        step(1, '0);
        repeat (4) step(0, '1);
        step(1, '1);
        repeat (8) step(0, '0);
        pattern = {256{2'b10}};
        step(1, pattern);
        repeat (8) step(0, ~pattern);
        // Every location exercises both endpoints as well as interior neighbors.
        for (integer seed = 0; seed < 512; seed = seed + 1) begin
            pattern = '0;
            pattern[seed] = 1'b1;
            step(1, pattern);
            repeat (3) step(0, '1);
        end
        // Original eight truth-table combinations, including the center bit.
        for (integer combo = 0; combo < 8; combo = combo + 1) begin
            pattern = '0;
            pattern[256:254] = combo[2:0];
            step(1, pattern);
            step(0, '0);
        end
        // Repeat loads verify priority; varied states check long-term evolution.
        for (integer trial = 0; trial < 40; trial = trial + 1) begin
            for (integer word_idx = 0; word_idx < 16; word_idx = word_idx + 1) begin
                rng = rng ^ (rng << 13);
                rng = rng ^ (rng >> 17);
                rng = rng ^ (rng << 5);
                pattern[word_idx*32 +: 32] = rng;
            end
            step(1, pattern);
            step(1, ~pattern);
            repeat (20) step(0, pattern);
        end
        $display("PASS Rule90 independent cell oracle: %0d checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
