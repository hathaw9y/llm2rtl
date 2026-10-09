`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic load = 1'b0;
    logic [511:0] data = '0;
    wire [511:0] q;
    logic [511:0] expected;
    logic [511:0] pattern;
    integer checks = 0;
    integer i, j, k;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;

    function automatic [511:0] rule_step(input logic [511:0] old_state);
        logic l, c, r;
        integer n;
        begin
            for (n = 0; n < 512; n = n + 1) begin
                if (n == 511) l = 1'b0;
                else l = old_state[n+1];
                c = old_state[n];
                if (n == 0) r = 1'b0;
                else r = old_state[n-1];
                case ({l,c,r})
                    3'b111: rule_step[n] = 1'b0;
                    3'b110: rule_step[n] = 1'b1;
                    3'b101: rule_step[n] = 1'b1;
                    3'b100: rule_step[n] = 1'b0;
                    3'b011: rule_step[n] = 1'b1;
                    3'b010: rule_step[n] = 1'b1;
                    3'b001: rule_step[n] = 1'b1;
                    3'b000: rule_step[n] = 1'b0;
                    default: rule_step[n] = 1'bx;
                endcase
            end
        end
    endfunction

    task automatic cycle(input logic do_load, input logic [511:0] value);
        logic [511:0] held;
        begin
            @(negedge clk);
            held = q;
            load = do_load;
            data = value;
            #1;
            if (q !== held) $fatal(1, "Output changed without positive edge");
            if (do_load) expected = value;
            else expected = rule_step(expected);
            @(posedge clk);
            #1;
            if (q !== expected)
                $fatal(1, "Mismatch at check %0d: got %h expected %h", checks, q, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        // No reset or specified power-up value: initialize using synchronous load.
        cycle(1'b1, '0);
        repeat (4) cycle(1'b0, '1);
        cycle(1'b1, '1);
        repeat (8) cycle(1'b0, '0);
        // Place each possible neighborhood in the interior.
        for (k = 0; k < 8; k = k + 1) begin
            pattern = '0;
            pattern[257:255] = k[2:0];
            cycle(1'b1, pattern);
            repeat (4) cycle(1'b0, '0);
        end
        // Each endpoint and adjacent cell, including no wraparound.
        for (k = 0; k < 4; k = k + 1) begin
            pattern = '0;
            case (k)
                0: pattern[0] = 1'b1;
                1: pattern[511] = 1'b1;
                2: pattern[1:0] = 2'b11;
                3: pattern[511:510] = 2'b11;
            endcase
            cycle(1'b1, pattern);
            repeat (20) cycle(1'b0, '1);
        end
        for (i = 0; i < 512; i = i + 1) pattern[i] = (i % 2 == 0);
        cycle(1'b1, pattern);
        repeat (40) cycle(1'b0, '0);
        // Consecutive loads and random trajectories exercise priority and simultaneous updates.
        for (j = 0; j < 20; j = j + 1) begin
            for (i = 0; i < 512; i = i + 1) pattern[i] = $urandom_range(0,1);
            cycle(1'b1, pattern);
            cycle(1'b1, ~pattern);
            repeat (30) cycle(1'b0, pattern);
        end
        $display("PASS Rule 110: %0d checked cycles", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Testbench timeout");
    end
endmodule
