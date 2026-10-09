`timescale 1ns/1ps
module dev_tb;
    reg clk=0, areset=0, bump_left=0, bump_right=0, ground=1, dig=0;
    wire walk_left, walk_right, aaah, digging;
    TopModule dut(.*);
    always #5 clk=~clk;
    // Behavioral oracle: activity and remembered direction are independent.
    integer activity=0, airborne_cycles=0, checks=0;
    reg facing_right=0;
    reg [3:0] expected;
    task check_outputs;
        begin
            expected=0;
            case(activity)
                0: if(facing_right) expected=4'b0100; else expected=4'b1000;
                1: expected=4'b0010;
                2: expected=4'b0001;
                3: expected=4'b0000;
            endcase
            if ({walk_left,walk_right,aaah,digging} !== expected)
                $fatal(1,"Mismatch t=%0t activity=%0d direction=%0b fall=%0d actual=%b expected=%b",$time,activity,facing_right,airborne_cycles,{walk_left,walk_right,aaah,digging},expected);
            checks=checks+1;
        end
    endtask
    always @(posedge clk or posedge areset) begin
        if(areset) begin activity=0; facing_right=0; airborne_cycles=0; end
        else begin
            case(activity)
                0: begin
                    if(!ground) begin activity=1; airborne_cycles=1; end
                    else if(dig) activity=2;
                    else if((!facing_right && bump_left) || (facing_right && bump_right))
                        facing_right=!facing_right;
                end
                1: begin
                    if(ground) begin
                        if(airborne_cycles>20) activity=3;
                        else activity=0;
                        airborne_cycles=0;
                    end else airborne_cycles=airborne_cycles+1;
                end
                2: if(!ground) begin activity=1; airborne_cycles=1; end
                3: activity=3;
            endcase
        end
        #1; check_outputs;
    end
    task step(input reg g,d,l,r);
        begin
            @(negedge clk); ground=g; dig=d; bump_left=l; bump_right=r;
            @(posedge clk); #2;
        end
    endtask
    task reset_machine;
        begin
            @(negedge clk); #2; areset=1;
            #2; if({walk_left,walk_right,aaah,digging}!==4'b1000)
                $fatal(1,"Asynchronous reset failed");
            @(negedge clk); areset=0; ground=1; dig=0; bump_left=0; bump_right=0;
        end
    endtask
    integer n,i;
    initial begin
        #1; areset=1; #2; areset=0;
        step(1,0,0,1); // irrelevant bump
        step(1,0,1,1); step(1,0,1,1); // both reverse
        step(1,1,1,1); // digging wins
        repeat(4) step(1,0,1,1); // digging persists
        step(0,1,1,1); step(1,1,1,1); // landing ignores dig and bumps
        step(1,0,1,0); // right
        step(0,1,1,1); step(0,1,1,1); step(1,1,1,1);
        // Exact short, threshold, and long fall lengths in both directions.
        for(n=1;n<=22;n=n+1) begin
            reset_machine;
            if(n%2) step(1,0,1,0);
            for(i=0;i<n;i=i+1) step(0,1,1,1);
            step(1,1,1,1);
            if(n>20) repeat(4) step(1,1,1,1);
        end
        reset_machine;
        step(1,0,1,0); step(1,1,1,1);
        repeat(300) step(0,1,1,1); // saturation must not wrap or kill in air
        step(1,0,0,0);
        repeat(10) step(0,1,1,1);
        reset_machine;
        for(i=0;i<1000;i=i+1) step($random,$random,$random,$random);
        $display("PASS: %0d behavioral checks",checks);
        $finish;
    end
    initial begin #50000; $fatal(1,"Timeout"); end
endmodule
