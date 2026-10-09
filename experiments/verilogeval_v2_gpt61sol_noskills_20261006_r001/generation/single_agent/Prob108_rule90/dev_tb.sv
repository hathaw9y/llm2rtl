`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg load = 0;
    reg [511:0] data = 0;
    wire [511:0] q;
    reg [511:0] expected;
    reg [511:0] next_expected;
    reg [511:0] pattern;
    integer checks = 0;
    integer i, j;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
    task step(input reg do_load, input reg [511:0] value);
        begin
            @(negedge clk);
            load = do_load;
            data = value;
            #1;
            if (q !== expected) $fatal(1, "State changed outside positive edge");
            if (do_load) next_expected = value;
            else begin
                for (integer k = 0; k < 512; k = k + 1) begin
                    if (k == 0) next_expected[k] = expected[1] ^ 1'b0;
                    else if (k == 511) next_expected[k] = expected[510] ^ 1'b0;
                    else next_expected[k] = expected[k-1] ^ expected[k+1];
                end
            end
            @(posedge clk);
            #1;
            expected = next_expected;
            checks = checks + 1;
            if (q !== expected) $fatal(1, "Mismatch at check %0d", checks);
        end
    endtask
    initial begin
        expected = {512{1'bx}};
        #1;
        if (q !== expected) $fatal(1, "Unexpected initialized state");
        step(0, 0);
        step(1, 0);
        repeat (4) step(0, {512{1'b1}});
        step(1, {512{1'b1}});
        repeat (10) step(0, 0);
        // Each single cell includes both boundaries and every interior index.
        for (i = 0; i < 512; i = i + 1) begin
            pattern = 0;
            pattern[i] = 1;
            step(1, pattern);
            repeat (3) step(0, 0);
        end
        pattern = {256{2'b10}};
        step(1, pattern);
        repeat (20) step(0, 0);
        for (i = 0; i < 40; i = i + 1) begin
            for (j = 0; j < 512; j = j + 1)
                pattern[j] = $urandom_range(0, 1);
            step(1, pattern);
            repeat (12) step(0, ~pattern);
        end
        // Consecutive load cycles must each replace the complete state.
        step(1, 512'b1);
        step(1, {1'b1, {511{1'b0}}});
        step(0, 0);
        $display("PASS Rule 90: %0d checks", checks);
        $finish;
    end
endmodule
