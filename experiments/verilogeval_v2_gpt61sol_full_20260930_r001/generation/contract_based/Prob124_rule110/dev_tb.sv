`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [511:0] data = 0;
    wire [511:0] q;
    logic [511:0] reference_state;
    logic [511:0] pattern;
    logic [31:0] prng = 32'h12345678;
    integer checks = 0;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;

    function automatic [511:0] evolve(input logic [511:0] state);
        logic l, c, r;
        for (integer i = 0; i < 512; i = i + 1) begin
            l = (i == 511) ? 1'b0 : state[i+1];
            c = state[i];
            r = (i == 0) ? 1'b0 : state[i-1];
            case ({l,c,r})
                3'b001, 3'b010, 3'b011, 3'b101, 3'b110: evolve[i] = 1'b1;
                default: evolve[i] = 1'b0;
            endcase
        end
    endfunction

    task automatic step(input logic do_load, input logic [511:0] value);
        logic [511:0] held;
        @(negedge clk);
        held = q;
        load = do_load;
        data = value;
        #1;
        if (q !== held) $fatal(1, "State changed without rising edge");
        if (do_load) reference_state = value;
        else reference_state = evolve(reference_state);
        @(posedge clk);
        #1;
        checks = checks + 1;
        if (q !== reference_state) $fatal(1, "Mismatch at check %0d", checks);
    endtask

    initial begin
        step(1, '0);
        repeat (5) step(0, '1);
        step(1, '1);
        repeat (5) step(0, '0);
        step(1, {256{2'b10}});
        repeat (10) step(0, '0);
        step(1, {256{2'b01}});
        repeat (10) step(0, '0);
        pattern = '0; pattern[0] = 1;
        step(1, pattern);
        repeat (20) step(0, '0);
        pattern = '0; pattern[511] = 1;
        step(1, pattern);
        repeat (20) step(0, '0);
        for (integer n = 0; n < 8; n = n + 1) begin
            pattern = '0;
            pattern[257:255] = n[2:0];
            step(1, pattern);
            step(0, '0);
        end
        // Consecutive synchronous loads override pending evolution.
        step(1, '1);
        step(1, '0);
        for (integer trial = 0; trial < 100; trial = trial + 1) begin
            for (integer bit_idx = 0; bit_idx < 512; bit_idx = bit_idx + 1) begin
                prng = prng ^ (prng << 13);
                prng = prng ^ (prng >> 17);
                prng = prng ^ (prng << 5);
                pattern[bit_idx] = prng[0];
            end
            step(1, pattern);
            repeat (10) step(0, ~pattern);
        end
        $display("PASS: %0d full-state edge checks and between-edge stability checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Development simulation timeout");
    end
endmodule
