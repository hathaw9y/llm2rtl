`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg load = 0;
    reg [511:0] data = 0;
    wire [511:0] q;
    reg [511:0] expected;
    reg [511:0] pattern;
    reg initialized = 0;
    integer checks = 0;
    integer i, j, k;
    reg [7:0] neighborhoods = 0;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;

    function automatic [511:0] step(input [511:0] old_state);
        integer n;
        reg l, c, r;
        begin
            for (n = 0; n < 512; n = n + 1) begin
                if (n == 511) l = 0;
                else l = old_state[n+1];
                c = old_state[n];
                if (n == 0) r = 0;
                else r = old_state[n-1];
                case ({l,c,r})
                    3'b111: step[n] = 0;
                    3'b110: step[n] = 1;
                    3'b101: step[n] = 1;
                    3'b100: step[n] = 0;
                    3'b011: step[n] = 1;
                    3'b010: step[n] = 1;
                    3'b001: step[n] = 1;
                    3'b000: step[n] = 0;
                    default: step[n] = 1'bx;
                endcase
            end
        end
    endfunction

    task automatic cycle(input reg do_load, input reg [511:0] value);
        begin
            @(negedge clk);
            load = do_load;
            data = value;
            #1;
            if (initialized && q !== expected)
                $fatal(1, "State changed without positive edge at check %0d", checks);
            if (do_load) expected = value;
            else expected = step(expected);
            @(posedge clk);
            #1;
            if (q !== expected)
                $fatal(1, "Mismatch at check %0d: got %h expected %h", checks, q, expected);
            initialized = 1;
            checks = checks + 1;
        end
    endtask

    initial begin
        // No defined startup value is required; first establish state with load.
        cycle(1, 512'b0);
        repeat (4) cycle(0, 0);
        cycle(1, {512{1'b1}});
        repeat (8) cycle(0, 0);
        for (i = 0; i < 512; i = i + 1) pattern[i] = i % 2;
        cycle(1, pattern);
        repeat (8) cycle(0, 0);
        cycle(1, ~pattern);
        repeat (8) cycle(0, 0);
        // Exhaust each truth-table row at an interior cell.
        for (k = 0; k < 8; k = k + 1) begin
            pattern = 0;
            pattern[257:255] = k;
            cycle(1, pattern);
            cycle(0, 0);
            neighborhoods[k] = 1;
        end
        // Both edges and interior isolated cells, propagated over many steps.
        for (k = 0; k < 3; k = k + 1) begin
            pattern = 0;
            if (k == 0) pattern[0] = 1;
            else if (k == 1) pattern[511] = 1;
            else pattern[256] = 1;
            cycle(1, pattern);
            repeat (32) cycle(0, 0);
        end
        // Back-to-back loads and arbitrary evolving states; data changes even
        // during non-load cycles to verify that it does not affect evolution.
        for (j = 0; j < 40; j = j + 1) begin
            for (i = 0; i < 512; i = i + 32) pattern[i +: 32] = $random;
            cycle(1, pattern);
            if (j % 2 == 0) cycle(1, ~pattern);
            repeat (12) cycle(0, ~pattern);
        end
        if (neighborhoods !== 8'hff) $fatal(1, "Missing truth-table coverage");
        $display("PASS Rule 110: %0d checked clock transitions", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
