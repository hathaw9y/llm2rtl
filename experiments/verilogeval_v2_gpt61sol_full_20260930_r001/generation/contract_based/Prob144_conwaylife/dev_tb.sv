module dev_tb;
    reg clk = 0;
    reg load = 0;
    reg [255:0] data = 0;
    wire [255:0] q;
    reg [255:0] expected, pattern, before_edge;
    integer checks = 0;
    integer trial, step, bit_index, loc, mask, row, col, dr, dc, n;
    integer seed = 144;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;
    initial begin #200000; $fatal(1, "Timeout"); end

    function automatic [255:0] evolve(input [255:0] state);
        integer r, c, dy, dx, count, rr, cc;
        begin
            evolve = 0;
            for (r=0; r<16; r=r+1)
                for (c=0; c<16; c=c+1) begin
                    count = 0;
                    for (dy=-1; dy<=1; dy=dy+1)
                        for (dx=-1; dx<=1; dx=dx+1)
                            if (dx != 0 || dy != 0) begin
                                rr=(r+dy+16)%16;
                                cc=(c+dx+16)%16;
                                if (state[rr*16+cc]) count=count+1;
                            end
                    case (count)
                        2: evolve[r*16+c]=state[r*16+c];
                        3: evolve[r*16+c]=1;
                        default: evolve[r*16+c]=0;
                    endcase
                end
        end
    endfunction

    task automatic tick(input reg loading, input reg [255:0] incoming);
        begin
            @(negedge clk);
            before_edge=q;
            load=loading;
            data=incoming;
            if (loading) expected=incoming;
            else expected=evolve(expected);
            #2;
            if (q !== before_edge) $fatal(1,"Asynchronous output change");
            @(posedge clk); #1;
            checks=checks+1;
            if (q !== expected) $fatal(1,"Mismatch check %0d: got %h expected %h", checks,q,expected);
        end
    endtask

    initial begin
        tick(1,256'b0);
        tick(0,256'b0);
        tick(1,{256{1'b1}});
        tick(0,0);
        for (loc=0;loc<256;loc=loc+1) begin
            pattern=0; pattern[loc]=1;
            tick(1,pattern); tick(0,0);
        end
        pattern=0; pattern[0]=1; pattern[15]=1; pattern[240]=1; pattern[255]=1;
        tick(1,pattern);
        repeat(4) tick(0,0);
        pattern=0; pattern[7*16+6]=1; pattern[7*16+7]=1; pattern[7*16+8]=1;
        tick(1,pattern);
        repeat(6) tick(0,0);
        // Exhaust all central-state/neighbor patterns at interior and wrapped boundaries.
        for (loc=0;loc<4;loc=loc+1) begin
            case(loc)
                0: begin row=0; col=0; end
                1: begin row=15; col=15; end
                2: begin row=0; col=7; end
                3: begin row=8; col=8; end
            endcase
            for (mask=0;mask<512;mask=mask+1) begin
                pattern=0; n=0;
                for (dr=-1;dr<=1;dr=dr+1)
                    for (dc=-1;dc<=1;dc=dc+1) begin
                        pattern[((row+dr+16)%16)*16+(col+dc+16)%16]=(mask>>n)&1;
                        n=n+1;
                    end
                tick(1,pattern); tick(0,0);
            end
        end
        for (trial=0;trial<40;trial=trial+1) begin
            for (bit_index=0;bit_index<256;bit_index=bit_index+1)
                pattern[bit_index]=$random(seed)&1;
            tick(1,pattern);
            repeat(12) tick(0,0);
        end
        tick(1,256'b1);
        tick(1,{256{1'b1}});
        tick(1,256'b0);
        $display("PASS: %0d edge comparisons",checks);
        $finish;
    end
endmodule
