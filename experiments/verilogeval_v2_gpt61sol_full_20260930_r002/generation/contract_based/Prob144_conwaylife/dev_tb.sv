`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [255:0] data = 0;
    wire [255:0] q;
    logic [255:0] expected;
    logic initialized = 0;
    integer checks = 0;
    logic [255:0] pattern;
    integer seed = 32'h1a23b45c;
    integer rr, cc, k, live, dr, dc, idx, trial, step;
    TopModule dut(.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;

    function automatic [255:0] evolve(input logic [255:0] old_grid);
        integer row, col, dy, dx, nr, nc, neighbours;
        begin
            evolve = '0;
            for (row = 0; row < 16; row = row + 1)
                for (col = 0; col < 16; col = col + 1) begin
                    neighbours = 0;
                    for (dy = -1; dy <= 1; dy = dy + 1)
                        for (dx = -1; dx <= 1; dx = dx + 1)
                            if (dy != 0 || dx != 0) begin
                                nr = (row + dy + 16) % 16;
                                nc = (col + dx + 16) % 16;
                                if (old_grid[nr*16+nc]) neighbours = neighbours + 1;
                            end
                    case (neighbours)
                        2: evolve[row*16+col] = old_grid[row*16+col];
                        3: evolve[row*16+col] = 1'b1;
                        default: evolve[row*16+col] = 1'b0;
                    endcase
                end
        end
    endfunction

    task automatic tick(input logic do_load, input logic [255:0] image);
        logic [255:0] before_edge;
        begin
            @(negedge clk);
            before_edge = q;
            load = do_load;
            data = image;
            #1;
            if (initialized && q !== before_edge)
                $fatal(1, "Output changed before positive edge");
            if (do_load) expected = image;
            else expected = evolve(expected);
            @(posedge clk);
            #1;
            if (q !== expected)
                $fatal(1, "Mismatch check %0d: expected %h got %h", checks, expected, q);
            initialized = 1;
            checks = checks + 1;
        end
    endtask

    initial begin
        tick(1, '0);
        tick(0, '1);
        tick(1, '1);
        tick(0, '0);
        tick(0, '1);
        // All possible neighbour counts, for both initial target states,
        // at every location including all wrap boundaries.
        for (rr = 0; rr < 16; rr = rr + 1)
            for (cc = 0; cc < 16; cc = cc + 1)
                for (live = 0; live <= 1; live = live + 1)
                    for (k = 0; k <= 8; k = k + 1) begin
                        pattern = '0;
                        pattern[rr*16+cc] = live;
                        idx = 0;
                        for (dr = -1; dr <= 1; dr = dr + 1)
                            for (dc = -1; dc <= 1; dc = dc + 1)
                                if (dr != 0 || dc != 0) begin
                                    if (idx < k)
                                        pattern[((rr+dr+16)%16)*16 + ((cc+dc+16)%16)] = 1;
                                    idx = idx + 1;
                                end
                        tick(1, pattern);
                        tick(0, ~pattern);
                    end
        // Stable block straddling both boundaries.
        pattern = '0;
        pattern[0] = 1; pattern[15] = 1;
        pattern[240] = 1; pattern[255] = 1;
        tick(1, pattern);
        repeat (4) tick(0, '0);
        // Horizontal oscillator wrapping the column boundary.
        pattern = '0;
        pattern[15] = 1; pattern[0] = 1; pattern[1] = 1;
        tick(1, pattern);
        repeat (8) tick(0, '1);
        // Deterministic pseudorandom grids with sustained autonomous evolution.
        for (trial = 0; trial < 30; trial = trial + 1) begin
            for (idx = 0; idx < 256; idx = idx + 1)
                pattern[idx] = ($random(seed) & 32'h7) < 3;
            tick(1, pattern);
            for (step = 0; step < 20; step = step + 1)
                tick(0, ~pattern);
        end
        // Held load replaces the entire grid on each edge.
        tick(1, '1);
        tick(1, '0);
        tick(1, 256'h123456789abcdef);
        tick(0, '0);
        $display("PASS %0d checked clock edges", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
