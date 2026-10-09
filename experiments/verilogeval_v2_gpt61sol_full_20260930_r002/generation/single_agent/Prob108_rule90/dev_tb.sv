`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [511:0] data = '0;
    wire [511:0] q;
    logic [511:0] expected = 'x;
    logic [511:0] next_expected;
    logic [511:0] pattern;
    integer cycles = 0;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));

    task automatic check_output;
        if (q !== expected)
            $fatal(1, "Mismatch at cycle %0d: q=%h expected=%h", cycles, q, expected);
    endtask

    // Independent scalar oracle using the old state of each neighbor.
    task automatic step(input logic do_load, input logic [511:0] value);
        load = do_load;
        data = value;
        #2;
        check_output();
        if (do_load) begin
            next_expected = value;
        end else begin
            for (integer cell_idx = 0; cell_idx < 512; cell_idx = cell_idx + 1) begin
                if (cell_idx == 0)
                    next_expected[cell_idx] = expected[1] ^ 1'b0;
                else if (cell_idx == 511)
                    next_expected[cell_idx] = expected[510] ^ 1'b0;
                else
                    next_expected[cell_idx] = expected[cell_idx-1] ^ expected[cell_idx+1];
            end
        end
        clk = 1;
        expected = next_expected;
        cycles = cycles + 1;
        #1;
        check_output();
        // Input changes while high cannot asynchronously load the state.
        data = ~value;
        load = ~do_load;
        #1;
        check_output();
        clk = 0;
        #1;
        check_output();
    endtask

    initial begin
        #1;
        check_output();
        step(0, '0); // No reset or initialization: unknown neighbors stay unknown.
        step(1, '0);
        repeat (4) step(0, '1);
        step(1, '1);
        repeat (4) step(0, '0);
        pattern = '0;
        pattern[0] = 1;
        step(1, pattern);
        repeat (8) step(0, '0);
        pattern = '0;
        pattern[511] = 1;
        step(1, pattern);
        repeat (8) step(0, '0);
        pattern = '0;
        pattern[255] = 1;
        step(1, pattern);
        repeat (260) step(0, '0);
        for (integer idx = 0; idx < 512; idx = idx + 1)
            pattern[idx] = idx % 2;
        step(1, pattern);
        repeat (8) step(0, '0);
        // Consecutive loads must each replace the previous state.
        step(1, '0);
        step(1, '1);
        for (integer trial = 0; trial < 80; trial = trial + 1) begin
            for (integer idx = 0; idx < 512; idx = idx + 1)
                pattern[idx] = $urandom_range(0, 1);
            step(1, pattern);
            repeat (5) step(0, '0);
        end
        $display("PASS Rule 90: %0d checked cycles", cycles);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
