`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [511:0] data = '0;
    wire [511:0] q;
    logic [511:0] expected;
    logic [511:0] pattern;
    logic [31:0] rng = 32'h13579bdf;
    integer checks = 0;
    integer i, j;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;

    function automatic [511:0] evolve(input logic [511:0] state);
        integer k;
        logic left_cell, right_cell;
        begin
            for (k = 0; k < 512; k = k + 1) begin
                left_cell = 0;
                right_cell = 0;
                if (k > 0) left_cell = state[k-1];
                if (k < 511) right_cell = state[k+1];
                evolve[k] = left_cell ^ right_cell;
            end
        end
    endfunction

    task automatic step(input logic do_load, input logic [511:0] value);
        logic [511:0] previous;
        begin
            @(negedge clk);
            if (checks > 0 && q !== expected) $fatal(1, "State changed on falling edge");
            previous = q;
            load = do_load;
            data = value;
            #1;
            if (q !== previous) $fatal(1, "Asynchronous state change");
            if (do_load) expected = value;
            else expected = evolve(expected);
            @(posedge clk);
            #1;
            checks = checks + 1;
            if (q !== expected) $fatal(1, "Mismatch at check %0d", checks);
        end
    endtask

    initial begin
        step(1, '0);
        repeat (4) step(0, '1);
        step(1, '1);
        repeat (6) step(0, '0);
        for (i = 0; i < 512; i = i + 1) pattern[i] = (i % 2 == 0);
        step(1, pattern);
        step(1, ~pattern);
        repeat (6) step(0, '0);
        for (i = 0; i < 512; i = i + 1) begin
            pattern = '0;
            pattern[i] = 1'b1;
            step(1, pattern);
            repeat (3) step(0, '1);
        end
        pattern = '0;
        pattern[256] = 1'b1;
        step(1, pattern);
        repeat (520) step(0, '0);
        for (i = 0; i < 300; i = i + 1) begin
            for (j = 0; j < 512; j = j + 1) begin
                rng = rng ^ (rng << 13);
                rng = rng ^ (rng >> 17);
                rng = rng ^ (rng << 5);
                pattern[j] = rng[0];
            end
            step((i % 7 < 2), pattern);
        end
        $display("PASS: %0d checked rising-edge updates", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Testbench watchdog timeout");
    end
endmodule
