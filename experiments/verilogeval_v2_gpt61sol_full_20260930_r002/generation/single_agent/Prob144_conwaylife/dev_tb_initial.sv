`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [255:0] data = 0;
    wire [255:0] q;
    logic [255:0] expected;
    logic [255:0] pattern;
    integer checks = 0;
    integer trial, cycle, bit_index, mask, alive, location;
    integer r, c, dr, dc, k, rr, cc;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;

    function automatic [255:0] evolve(input logic [255:0] grid);
        integer cell_index, neighbor_index, nr, nc, count;
        begin
            evolve = '0;
            for (cell_index = 0; cell_index < 256; cell_index = cell_index + 1) begin
                count = 0;
                // Enumerate all cells and use toroidal distances, independently
                // of the DUT's explicit eight-neighbor wiring.
                for (neighbor_index = 0; neighbor_index < 256; neighbor_index = neighbor_index + 1) begin
                    nr = (neighbor_index / 16 - cell_index / 16 + 16) % 16;
                    nc = (neighbor_index % 16 - cell_index % 16 + 16) % 16;
                    if ((nr == 0 || nr == 1 || nr == 15) &&
                        (nc == 0 || nc == 1 || nc == 15) &&
                        neighbor_index != cell_index)
                        count = count + grid[neighbor_index];
                end
                case (count)
                    2: evolve[cell_index] = grid[cell_index];
                    3: evolve[cell_index] = 1'b1;
                    default: evolve[cell_index] = 1'b0;
                endcase
            end
        end
    endfunction

    task automatic step(input logic loading, input logic [255:0] payload);
        logic [255:0] before_edge;
        begin
            @(negedge clk);
            before_edge = q;
            load = loading;
            data = payload;
            if (loading) expected = payload;
            else expected = evolve(expected);
            #1;
            if (q !== before_edge) $fatal(1, "State changed before rising edge");
            @(posedge clk);
            #1;
            if (q !== expected)
                $fatal(1, "Mismatch check %0d expected=%h actual=%h", checks, expected, q);
            checks = checks + 1;
        end
    endtask

    initial begin
        #1;
        if (q !== {256{1'bx}}) $fatal(1, "Unexpected initialized state");
        step(1, '0);
        step(0, '1);
        step(1, '1);
        step(0, '0);
        step(0, '1);
        // Exhaust all 256 neighbor patterns for dead and live centers,
        // at an interior cell and every type of wrapping boundary.
        for (location = 0; location < 5; location = location + 1) begin
            case (location)
                0: begin r=0; c=0; end
                1: begin r=15; c=15; end
                2: begin r=0; c=8; end
                3: begin r=8; c=15; end
                4: begin r=8; c=8; end
            endcase
            for (alive = 0; alive < 2; alive = alive + 1) begin
                for (mask = 0; mask < 256; mask = mask + 1) begin
                    pattern = '0;
                    pattern[r*16+c] = (alive == 1);
                    k = 0;
                    for (dr=-1; dr<=1; dr=dr+1)
                        for (dc=-1; dc<=1; dc=dc+1)
                            if (dr != 0 || dc != 0) begin
                                rr = (r+dr+16)%16;
                                cc = (c+dc+16)%16;
                                pattern[rr*16+cc] = (mask >> k) & 1;
                                k=k+1;
                            end
                    step(1, pattern);
                    step(0, ~pattern);
                end
            end
        end
        // A blinker crossing the left/right seam evolves repeatedly.
        pattern = '0;
        pattern[8*16+15] = 1;
        pattern[8*16+0] = 1;
        pattern[8*16+1] = 1;
        step(1, pattern);
        repeat (8) step(0, '0);
        for (trial=0; trial<12; trial=trial+1) begin
            for (bit_index=0; bit_index<256; bit_index=bit_index+1)
                pattern[bit_index] = ($urandom_range(0, 3) == 0);
            step(1, pattern);
            for (cycle=0; cycle<10; cycle=cycle+1) step(0, '1);
        end
        $display("PASS %0d grid checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Test timeout");
    end
endmodule
