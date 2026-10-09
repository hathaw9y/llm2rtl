`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [255:0] data = '0;
    wire [255:0] q;
    logic [255:0] expected = '0;
    logic [255:0] pattern;
    integer checks = 0;
    TopModule dut(.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;
    function automatic [255:0] evolve(input logic [255:0] grid);
        integer r, c, dr, dc, rr, cc, count;
        begin
            evolve = '0;
            for (r = 0; r < 16; r = r + 1)
                for (c = 0; c < 16; c = c + 1) begin
                    count = 0;
                    for (dr = -1; dr <= 1; dr = dr + 1)
                        for (dc = -1; dc <= 1; dc = dc + 1)
                            if ((dr != 0) || (dc != 0)) begin
                                rr = r + dr;
                                cc = c + dc;
                                if (rr < 0) rr = 15;
                                if (rr > 15) rr = 0;
                                if (cc < 0) cc = 15;
                                if (cc > 15) cc = 0;
                                if (grid[rr*16+cc]) count = count + 1;
                            end
                    case (count)
                        2: evolve[r*16+c] = grid[r*16+c];
                        3: evolve[r*16+c] = 1'b1;
                        default: evolve[r*16+c] = 1'b0;
                    endcase
                end
        end
    endfunction
    task automatic cycle(input bit do_load, input logic [255:0] value);
        begin
            @(negedge clk);
            load = do_load;
            data = value;
            if (do_load) expected = value;
            else expected = evolve(expected);
            @(posedge clk);
            #1;
            checks = checks + 1;
            if (q !== expected) $fatal(1, "FAIL cycle %0d expected=%h actual=%h", checks, expected, q);
        end
    endtask
    initial begin
        cycle(1, '0);
        repeat (3) cycle(0, '0);
        cycle(1, '1);
        repeat (3) cycle(0, '0);
        // Stable block straddling both toroidal boundaries.
        pattern = '0;
        pattern[0] = 1; pattern[15] = 1;
        pattern[240] = 1; pattern[255] = 1;
        cycle(1, pattern);
        repeat (4) cycle(0, '0);
        // Oscillator crossing the column boundary.
        pattern = '0;
        pattern[8*16+15] = 1; pattern[8*16] = 1; pattern[8*16+1] = 1;
        cycle(1, pattern);
        repeat (6) cycle(0, '0);
        // Every single-cell initial position.
        for (integer k = 0; k < 256; k = k + 1) begin
            pattern = '0;
            pattern[k] = 1;
            cycle(1, pattern);
            cycle(0, '0);
        end
        // Dense and sparse random loads, including consecutive loads.
        for (integer trial = 0; trial < 40; trial = trial + 1) begin
            for (integer k = 0; k < 256; k = k + 1)
                pattern[k] = ($urandom_range(0, 7) < (trial % 8));
            cycle(1, pattern);
            repeat (8) cycle(0, '0);
            cycle(1, ~pattern);
            cycle(1, pattern);
        end
        $display("PASS: %0d checked cycles", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "FAIL timeout");
    end
endmodule
