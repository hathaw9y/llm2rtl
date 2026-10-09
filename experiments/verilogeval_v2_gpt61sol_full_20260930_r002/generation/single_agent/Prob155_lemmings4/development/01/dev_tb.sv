`timescale 1ns/1ps
module dev_tb;
    logic clk=0, areset=0;
    logic bump_left=0, bump_right=0, ground=1, dig=0;
    wire walk_left, walk_right, aaah, digging;
    TopModule dut(.*);
    always #5 clk=~clk;

    // Behavioral oracle: activity and remembered direction are separate.
    // Fall length is measured from clock timestamps, not a DUT-like counter.
    integer activity=0; // 0 walk, 1 dig, 2 fall, 3 splattered
    bit rightward=0;
    time fall_started;
    integer checks=0;
    task automatic check_outputs;
        reg [3:0] expected;
        begin
            expected=4'b0000;
            case(activity)
                0: if(rightward) expected=4'b0100;
                   else expected=4'b1000;
                1: expected=4'b0001;
                2: expected=4'b0010;
                3: expected=4'b0000;
            endcase
            if ({walk_left,walk_right,aaah,digging} !== expected)
                $fatal(1,"Mismatch at %0t: got %b expected %b activity %0d",$time,
                       {walk_left,walk_right,aaah,digging},expected,activity);
            checks=checks+1;
        end
    endtask
    always @(posedge clk or posedge areset) begin
        if(areset) begin
            activity=0;
            rightward=0;
            fall_started=0;
        end else begin
            case(activity)
                0: begin
                    if(!ground) begin activity=2; fall_started=$time; end
                    else if(dig) activity=1;
                    else if((rightward && bump_right) || (!rightward && bump_left))
                        rightward=!rightward;
                end
                1: if(!ground) begin activity=2; fall_started=$time; end
                2: if(ground) begin
                    if (($time-fall_started) > 200) activity=3;
                    else activity=0;
                end
                3: activity=3;
            endcase
        end
        #1; check_outputs();
    end
    task automatic step(input bit g, d, bl, br);
        begin
            @(negedge clk);
            ground=g; dig=d; bump_left=bl; bump_right=br;
            #1; check_outputs(); // Moore outputs must not follow input changes.
            @(posedge clk); #2;
        end
    endtask
    task automatic reset_machine;
        begin
            @(negedge clk); #2; areset=1;
            #2; check_outputs();
            areset=0;
        end
    endtask
    task automatic fall_test(input integer length, input bit dir, from_dig);
        integer i;
        begin
            reset_machine();
            step(1,0,dir,0);
            if(from_dig) begin
                step(1,1,1,1);
                repeat(3) step(1,0,1,1);
            end
            for(i=0;i<length;i=i+1) step(0,1,1,1);
            step(1,1,1,1);
            if(length>20) begin
                repeat(4) step(1,1,1,1);
                step(0,0,0,0);
            end else begin
                step(1,0,0,0);
            end
        end
    endtask
    integer n;
    initial begin
        #1; areset=1;
        #2; areset=0;
        step(1,0,0,1); // opposite-side bump ignored
        step(1,0,1,1); // both sides reverse left to right
        step(1,0,1,0); // opposite-side bump ignored
        step(1,0,1,1); // both sides reverse right to left
        step(1,1,1,1); // dig beats bumps
        repeat(4) step(1,0,1,1);
        step(0,1,1,1); // falling beats dig
        step(1,1,1,1); // landing preserves direction and ignores dig
        for(n=1;n<=22;n=n+1) begin
            fall_test(n,0,0);
            fall_test(n,1,1);
        end
        fall_test(80,1,0);
        fall_test(300,0,1);
        reset_machine();
        // Separate short falls must not accumulate.
        repeat(4) begin
            repeat(15) step(0,0,0,0);
            step(1,0,0,0);
        end
        for(n=0;n<500;n=n+1)
            step($urandom_range(0,1),$urandom_range(0,1),
                 $urandom_range(0,1),$urandom_range(0,1));
        reset_machine();
        step(1,0,0,0);
        $display("PASS: %0d output checks",checks);
        $finish;
    end
    initial begin
        #100000; $fatal(1,"Timeout");
    end
endmodule
