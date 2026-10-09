`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg load = 0;
    reg [511:0] data = 0;
    wire [511:0] q;
    reg [511:0] expected;
    reg [511:0] next_expected;
    reg [511:0] pattern;
    reg known = 0;
    integer checks = 0;
    integer i, j, k;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;

    task cycle(input reg do_load, input reg [511:0] value);
        integer cell_index;
        reg left_cell, right_cell;
        begin
            @(negedge clk);
            load = do_load;
            data = value;
            #1;
            if (known && q !== expected)
                $fatal(1, "State changed before rising edge, check %0d", checks);
            if (do_load)
                next_expected = value;
            else begin
                for (cell_index = 0; cell_index < 512; cell_index = cell_index + 1) begin
                    if (cell_index == 0) left_cell = 0;
                    else left_cell = expected[cell_index-1];
                    if (cell_index == 511) right_cell = 0;
                    else right_cell = expected[cell_index+1];
                    next_expected[cell_index] = left_cell ^ right_cell;
                end
            end
            @(posedge clk);
            #1;
            if (q !== next_expected)
                $fatal(1, "Rule 90/load mismatch, check %0d: got %h expected %h", checks, q, next_expected);
            expected = next_expected;
            known = 1;
            checks = checks + 1;
            #2;
            if (q !== expected) $fatal(1, "State unstable after rising edge");
        end
    endtask

    initial begin
        // No assertion about unspecified power-up state; first load establishes it.
        cycle(1, 512'b0);
        repeat (5) cycle(0, {512{1'b1}});
        cycle(1, {512{1'b1}});
        repeat (8) cycle(0, 512'b0);
        for (j = 0; j < 5; j = j + 1) begin
            pattern = 0;
            case (j)
                0: pattern[0] = 1;
                1: pattern[511] = 1;
                2: pattern[1] = 1;
                3: pattern[510] = 1;
                4: pattern[256] = 1;
            endcase
            cycle(1, pattern);
            repeat (20) cycle(0, ~pattern);
        end
        for (i = 0; i < 512; i = i + 1) pattern[i] = i % 2;
        cycle(1, pattern);
        cycle(1, ~pattern);
        repeat (20) cycle(0, pattern);
        for (k = 0; k < 12; k = k + 1) begin
            for (i = 0; i < 512; i = i + 1) pattern[i] = $random;
            cycle(1, pattern);
            repeat (45) cycle(0, ~pattern);
        end
        $display("PASS Rule 90: %0d checked cycles", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
