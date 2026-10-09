`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg load = 0;
    reg [255:0] data = 0;
    wire [255:0] q;
    reg [255:0] model;
    reg [255:0] pattern;
    integer checks = 0;
    integer n, alive, i, j, k;
    integer neighbors [0:7];
    reg [31:0] rng = 32'h42c0ffee;
    TopModule dut(.clk(clk), .load(load), .data(data), .q(q));

    function automatic [255:0] advance(input [255:0] state);
        integer row, col, dr, dc, rr, cc, total;
        begin
            advance = 0;
            for (row = 0; row < 16; row = row + 1)
                for (col = 0; col < 16; col = col + 1) begin
                    total = 0;
                    for (dr = -1; dr <= 1; dr = dr + 1)
                        for (dc = -1; dc <= 1; dc = dc + 1)
                            if (dr != 0 || dc != 0) begin
                                rr = (row + dr + 16) % 16;
                                cc = (col + dc + 16) % 16;
                                if (state[rr*16+cc]) total = total + 1;
                            end
                    case (total)
                        2: advance[row*16+col] = state[row*16+col];
                        3: advance[row*16+col] = 1;
                        default: advance[row*16+col] = 0;
                    endcase
                end
        end
    endfunction

    task automatic tick(input reg loading, input reg [255:0] value);
        reg [255:0] before_edge;
        begin
            clk = 0;
            before_edge = q;
            load = loading;
            data = value;
            #4;
            if (q !== before_edge) $fatal(1, "State changed before positive edge");
            if (loading) model = value;
            else model = advance(model);
            clk = 1;
            #1;
            checks = checks + 1;
            if (q !== model)
                $fatal(1, "State mismatch at check %0d: got %h expected %h", checks, q, model);
            #4;
            clk = 0;
            #1;
            if (q !== model) $fatal(1, "State changed at negative edge");
        end
    endtask

    initial begin
        #1;
        if (q !== {256{1'bx}}) $fatal(1, "Unexpected initialized state without load");
        tick(1, 0);
        repeat (3) tick(0, '1);
        tick(1, '1);
        tick(0, 0);
        repeat (2) tick(0, '1);
        // All neighbor counts, dead/alive center, at a corner crossing both seams.
        neighbors[0]=255; neighbors[1]=240; neighbors[2]=241;
        neighbors[3]=15; neighbors[4]=1;
        neighbors[5]=31; neighbors[6]=16; neighbors[7]=17;
        for (alive = 0; alive <= 1; alive = alive + 1)
            for (n = 0; n <= 8; n = n + 1) begin
                pattern = 0;
                pattern[0] = alive;
                for (i = 0; i < n; i = i + 1) pattern[neighbors[i]] = 1;
                tick(1, pattern);
                tick(0, 0);
                repeat (3) tick(0, '1);
            end
        // Blinker crossing the horizontal seam.
        pattern = 0; pattern[127]=1; pattern[112]=1; pattern[113]=1;
        tick(1, pattern);
        repeat (8) tick(0, 0);
        // Stable block crossing both seams.
        pattern = 0; pattern[0]=1; pattern[15]=1; pattern[240]=1; pattern[255]=1;
        tick(1, pattern);
        repeat (8) tick(0, 0);
        // Single live cell at each vector position.
        for (j = 0; j < 256; j = j + 1) begin
            pattern = 0; pattern[j] = 1;
            tick(1, pattern);
            tick(0, 0);
        end
        // Reproducible varied states and multiple generations, including consecutive loads.
        for (j = 0; j < 40; j = j + 1) begin
            for (k = 0; k < 256; k = k + 1) begin
                rng = rng ^ (rng << 13);
                rng = rng ^ (rng >> 17);
                rng = rng ^ (rng << 5);
                pattern[k] = rng[0];
            end
            tick(1, pattern);
            if (j % 4 != 0) repeat (10) tick(0, ~pattern);
        end
        $display("PASS: %0d checked cycles", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Bounded simulation timeout");
    end
endmodule
