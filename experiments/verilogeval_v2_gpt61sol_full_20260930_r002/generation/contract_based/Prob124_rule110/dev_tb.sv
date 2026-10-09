`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [511:0] data = '0;
    wire [511:0] q;
    logic [511:0] expected;
    logic [511:0] pattern;
    integer checks = 0;
    integer n, i, k;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;

    function automatic [511:0] evolve(input logic [511:0] prior);
        logic l, c, r;
        integer j;
        begin
            for (j = 0; j < 512; j = j + 1) begin
                if (j == 511) l = 0; else l = prior[j+1];
                c = prior[j];
                if (j == 0) r = 0; else r = prior[j-1];
                case ({l,c,r})
                    3'b111: evolve[j] = 0;
                    3'b110: evolve[j] = 1;
                    3'b101: evolve[j] = 1;
                    3'b100: evolve[j] = 0;
                    3'b011: evolve[j] = 1;
                    3'b010: evolve[j] = 1;
                    3'b001: evolve[j] = 1;
                    3'b000: evolve[j] = 0;
                    default: evolve[j] = 1'bx;
                endcase
            end
        end
    endfunction

    task automatic cycle(input logic ld, input logic [511:0] value);
        logic [511:0] held;
        begin
            @(negedge clk);
            held = q;
            load = ld;
            data = value;
            #2;
            if (q !== held) $fatal(1, "State changed without positive edge");
            if (ld) expected = value;
            else expected = evolve(expected);
            @(posedge clk);
            #1;
            if (q !== expected)
                $fatal(1, "Mismatch at check %0d: q=%h expected=%h", checks, q, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        // No initial-state assertion: the original specifies no power-up state.
        cycle(1, '0);
        repeat (4) cycle(0, '1);
        cycle(1, '1);
        repeat (8) cycle(0, '0);
        cycle(1, '0);
        cycle(1, '1);
        cycle(1, '0);
        pattern = '0; pattern[0] = 1;
        cycle(1, pattern);
        repeat (16) cycle(0, '0);
        pattern = '0; pattern[511] = 1;
        cycle(1, pattern);
        repeat (16) cycle(0, '1);
        for (i = 0; i < 512; i = i + 1) pattern[i] = i % 2;
        cycle(1, pattern);
        repeat (16) cycle(0, '0);
        cycle(1, ~pattern);
        repeat (16) cycle(0, '0);
        // Each table row at each interior position, with zero-filled surroundings.
        for (i = 1; i < 511; i = i + 1) begin
            for (n = 0; n < 8; n = n + 1) begin
                pattern = '0;
                pattern[i+1] = (n >> 2) & 1;
                pattern[i] = (n >> 1) & 1;
                pattern[i-1] = n & 1;
                cycle(1, pattern);
                cycle(0, '0);
            end
        end
        for (n = 0; n < 40; n = n + 1) begin
            for (k = 0; k < 16; k = k + 1)
                pattern[k*32 +: 32] = $urandom;
            cycle(1, pattern);
            repeat (25) cycle(0, ~pattern);
        end
        $display("PASS Rule 110: %0d complete-vector checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
