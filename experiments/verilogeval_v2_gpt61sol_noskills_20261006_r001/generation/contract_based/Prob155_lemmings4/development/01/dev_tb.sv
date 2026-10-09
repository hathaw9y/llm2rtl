`timescale 1ns/1ps
module dev_tb;
    reg clk=0, areset=0, bump_left=0, bump_right=0, ground=1, dig=0;
    wire walk_left, walk_right, aaah, digging;
    TopModule dut(.*);
    always #5 clk=~clk;
    // Oracle uses activity and remembered direction separately, and an
    // unbounded duration rather than the DUT's encoded directional states.
    integer mode=0, duration=0, checked=0;
    reg rightward=0;
    reg [3:0] expected;
    integer i,j,n;
    reg [31:0] rng=32'h5831acd9;
    task check;
        begin
            case(mode)
                0: if (rightward) expected=4'b0100; else expected=4'b1000;
                1: expected=4'b0010;
                2: expected=4'b0001;
                3: expected=4'b0000;
            endcase
            if ({walk_left,walk_right,aaah,digging} !== expected)
                $fatal(1,"Mismatch t=%0t mode=%0d direction=%0d duration=%0d expected=%b got=%b",$time,mode,rightward,duration,expected,{walk_left,walk_right,aaah,digging});
            checked=checked+1;
        end
    endtask
    always @(posedge clk or posedge areset) begin
        if (areset) begin mode=0; rightward=0; duration=0; end
        else case(mode)
            0: begin
                duration=0;
                if (!ground) begin mode=1; duration=1; end
                else if (dig) mode=2;
                else if ((!rightward && bump_left) || (rightward && bump_right)) rightward=!rightward;
            end
            1: begin
                if (ground) begin
                    if (duration>20) mode=3;
                    else mode=0;
                    duration=0;
                end else duration=duration+1;
            end
            2: if (!ground) begin mode=1; duration=1; end
            3: mode=3;
        endcase
        #1; check;
    end
    task step(input reg g, d, bl, br);
        begin
            @(negedge clk);
            ground=g; dig=d; bump_left=bl; bump_right=br;
            #1; check; // Inputs alone must not change Moore outputs.
            @(posedge clk); #2;
        end
    endtask
    task reset_now;
        begin
            @(negedge clk); #2; areset=1;
            #2; check;
            areset=0;
        end
    endtask
    initial begin
        #2; areset=1; #2; check; areset=0;
        step(1,0,0,1); // opposite-side bump has no effect
        step(1,0,1,1); step(1,0,1,0); step(1,0,0,1);
        step(1,1,1,1); // dig overrides reversal
        step(1,0,1,1); step(1,1,1,1); // persistent digging
        step(0,1,1,1); step(0,1,1,1); step(1,1,1,1);
        step(1,0,1,0); // rightward
        step(0,1,1,1); step(1,1,1,1); // direction retained
        reset_now;
        // Exhaustive walking priorities for both directions.
        for (j=0;j<2;j=j+1) begin
            for (i=0;i<16;i=i+1) begin
                reset_now;
                if(j) step(1,0,1,0);
                step((i>>3)&1,(i>>2)&1,(i>>1)&1,i&1);
                step(1,1,1,1);
            end
        end
        // Threshold and much longer falls, in each direction and from digging.
        for(j=0;j<2;j=j+1) begin
            for(n=19;n<=22;n=n+1) begin
                reset_now;
                if(j) step(1,0,1,0);
                if(n&1) step(1,1,1,1);
                for(i=0;i<n;i=i+1) step(0,i&1,1,1);
                step(1,1,1,1);
                if(n>20) begin
                    step(0,1,1,1); step(1,0,1,1);
                end
            end
            reset_now;
            if(j) step(1,0,1,0);
            for(i=0;i<1000;i=i+1) step(0,1,1,1);
            step(1,1,1,1);
            step(0,0,0,0);
        end
        // Independent fall episodes must not accumulate duration.
        reset_now;
        for(j=0;j<5;j=j+1) begin
            for(i=0;i<20;i=i+1) step(0,0,0,0);
            step(1,0,0,0);
        end
        step(0,0,0,0); reset_now; // async reset in midair
        step(1,1,0,0); reset_now; // async reset while digging
        for(i=0;i<2000;i=i+1) begin
            rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5);
            if(i%83==0) reset_now;
            step(rng[0],rng[1],rng[2],rng[3]);
        end
        $display("PASS: %0d Moore, reset, priority, duration and randomized checks",checked);
        $finish;
    end
    initial begin #100000; $fatal(1,"Timeout"); end
endmodule
