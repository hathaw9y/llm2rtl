`timescale 1ns/1ps
module dev_tb;
    reg clk=0, reset=0, data=0, ack=0;
    wire [3:0] count;
    wire counting, done;
    TopModule dut(.clk(clk), .reset(reset), .data(data), .ack(ack),
                  .count(count), .counting(counting), .done(done));
    always #5 clk = ~clk;

    // Independent oracle: raw serial window and total duration in cycles.
    integer mode=0, valid=0, captured=0, duration=0, elapsed=0;
    integer expected_count, checks=0, d, j;
    reg [3:0] window=0;
    reg expected_counting, expected_done;
    task step(input reg r, input reg b, input reg a);
        begin
            @(negedge clk);
            reset=r; data=b; ack=a;
            @(posedge clk);
            if (r) begin
                mode=0; valid=0; window=0; captured=0;
                duration=0; elapsed=0;
            end else begin
                case (mode)
                    0: begin
                        window={window[2:0], b};
                        if (valid<4) valid=valid+1;
                        if (valid==4 && window==4'b1101) begin
                            mode=1; captured=0; duration=0;
                        end
                    end
                    1: begin
                        duration=duration*2+b;
                        captured=captured+1;
                        if (captured==4) begin mode=2; elapsed=0; end
                    end
                    2: begin
                        elapsed=elapsed+1;
                        if (elapsed==(duration+1)*1000) mode=3;
                    end
                    3: if (a) begin mode=0; valid=0; window=0; end
                endcase
            end
            expected_counting=(mode==2);
            expected_done=(mode==3);
            expected_count=duration-elapsed/1000;
            #1;
            checks=checks+1;
            if (counting !== expected_counting || done !== expected_done)
                $fatal(1,"Control mismatch check=%0d mode=%0d elapsed=%0d counting=%b done=%b",checks,mode,elapsed,counting,done);
            if (mode==2 && count !== expected_count[3:0])
                $fatal(1,"Count mismatch check=%0d elapsed=%0d got=%0d expected=%0d",checks,elapsed,count,expected_count);
        end
    endtask
    task start_timer(input integer value);
        begin
            // Three consecutive ones exercise overlapping search prefixes.
            step(0,1,0); step(0,1,0); step(0,1,0);
            step(0,0,0); step(0,1,0);
            for (integer k=3;k>=0;k=k-1) step(0,(value>>k)&1,0);
            if (mode!=2) $fatal(1,"Stimulus failed to start timer");
        end
    endtask
    initial begin
        step(1,1,1);
        // Reset interrupts a partial prefix and capture.
        step(0,1,0); step(0,1,0); step(1,0,0);
        step(0,0,0); step(0,1,0); step(0,0,0);
        step(0,1,0); step(0,1,0); step(0,0,0); step(0,1,0);
        step(0,1,0); step(0,0,0); step(1,1,1);
        start_timer(15);
        repeat (1001) step(0,1,1);
        step(1,1,1);
        for (d=0;d<16;d=d+1) begin
            start_timer(d);
            for (j=0;j<(d+1)*1000;j=j+1)
                step(0,((j%4)==0 || (j%4)==1 || (j%4)==3),j%2);
            repeat (7) step(0,1,0);
            if (d==7) step(1,1,1);
            else step(0,1,1);
            // Ack-edge data is ignored; these bits alone cannot trigger.
            step(0,1,0); step(0,0,0); step(0,1,0);
            step(1,0,0);
        end
        $display("PASS timer specification checked across all delays (%0d edges)",checks);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1,"Bounded timeout");
    end
endmodule
