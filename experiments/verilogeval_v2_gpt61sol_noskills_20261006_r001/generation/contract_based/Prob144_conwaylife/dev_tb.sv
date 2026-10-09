`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg load = 0;
    reg [255:0] data = 0;
    wire [255:0] q;
    reg [255:0] model;
    reg [255:0] pattern;
    reg [31:0] rng = 32'h9e3779b9;
    integer checks = 0;
    integer alive, count, k, i, j, trial, stepno, row, col, dr, dc;
    TopModule dut(.clk(clk), .load(load), .data(data), .q(q));

    function automatic [255:0] evolve(input [255:0] old);
        integer rr, cc, dy, dx, nr, nc, n;
        begin
            evolve = 0;
            for (rr=0; rr<16; rr=rr+1)
                for (cc=0; cc<16; cc=cc+1) begin
                    n = 0;
                    for (dy=-1; dy<=1; dy=dy+1)
                        for (dx=-1; dx<=1; dx=dx+1)
                            if (dy != 0 || dx != 0) begin
                                nr = (rr+dy+16)%16;
                                nc = (cc+dx+16)%16;
                                if (old[nr*16+nc]) n=n+1;
                            end
                    case (n)
                        2: evolve[rr*16+cc] = old[rr*16+cc];
                        3: evolve[rr*16+cc] = 1;
                        default: evolve[rr*16+cc] = 0;
                    endcase
                end
        end
    endfunction

    task automatic cycle(input reg loading, input reg [255:0] value);
        reg [255:0] before_edge;
        begin
            clk = 0;
            before_edge = q;
            load = loading;
            data = value;
            #2;
            if (q !== before_edge) $fatal(1,"State changed without rising edge");
            if (loading) model = value;
            else model = evolve(model);
            clk = 1;
            #1;
            checks = checks+1;
            if (q !== model) $fatal(1,"Mismatch check %0d got %h expected %h",checks,q,model);
            clk = 0;
            #1;
            if (q !== model) $fatal(1,"State changed on falling edge");
        end
    endtask

    initial begin
        cycle(1, 256'b0);
        repeat (4) cycle(0, ~256'b0);
        cycle(1, ~256'b0);
        repeat (4) cycle(0, 0);
        // Consecutive loads override evolution on each rising edge.
        cycle(1, 256'h123456789abcdef);
        cycle(1, 256'hfedcba987654321);
        cycle(0, 0);

        // Check every neighbour count for both live and dead cells.
        // Exercise both an interior cell and each corner.
        for (trial=0; trial<5; trial=trial+1) begin
            case (trial)
                0: begin row=7; col=9; end
                1: begin row=0; col=0; end
                2: begin row=0; col=15; end
                3: begin row=15; col=0; end
                4: begin row=15; col=15; end
            endcase
            for (alive=0; alive<=1; alive=alive+1)
                for (count=0; count<=8; count=count+1) begin
                    pattern = 0;
                    pattern[row*16+col] = alive;
                    k=0;
                    for (dr=-1; dr<=1; dr=dr+1)
                        for (dc=-1; dc<=1; dc=dc+1)
                            if (dr!=0 || dc!=0) begin
                                if (k<count)
                                    pattern[((row+dr+16)%16)*16+(col+dc+16)%16]=1;
                                k=k+1;
                            end
                    cycle(1, pattern);
                    cycle(0, 0);
                    if (count==2) begin
                        if (q[row*16+col] !== (alive!=0)) $fatal(1,"Count two retention failed");
                    end else if (count==3) begin
                        if (q[row*16+col] !== 1'b1) $fatal(1,"Count three birth failed");
                    end else begin
                        if (q[row*16+col] !== 1'b0) $fatal(1,"Death rule failed");
                    end
                end
        end
        // A blinker crossing the column seam oscillates through the row seam.
        pattern=0; pattern[15]=1; pattern[0]=1; pattern[1]=1;
        cycle(1,pattern);
        repeat (12) cycle(0,0);
        // A stable block straddles both seams.
        pattern=0; pattern[0]=1; pattern[15]=1; pattern[240]=1; pattern[255]=1;
        cycle(1,pattern);
        repeat (6) begin
            cycle(0,0);
            if (q !== pattern) $fatal(1,"Wrapped block changed");
        end
        // Isolated cells, including all boundary positions.
        for (i=0; i<256; i=i+1) begin
            pattern=0; pattern[i]=1;
            cycle(1,pattern);
            cycle(0,0);
            if (q !== 256'b0) $fatal(1,"Isolated cell survived");
        end
        // Deterministic binary random loads and multicycle evolution.
        for (trial=0; trial<40; trial=trial+1) begin
            for (j=0; j<256; j=j+1) begin
                rng = rng ^ (rng << 13);
                rng = rng ^ (rng >> 17);
                rng = rng ^ (rng << 5);
                pattern[j]=rng[0];
            end
            cycle(1,pattern);
            for (stepno=0; stepno<20; stepno=stepno+1) cycle(0,~pattern);
        end
        $display("PASS: %0d synchronous load and toroidal evolution checks",checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"Timeout");
    end
endmodule
