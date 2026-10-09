`timescale 1ns/1ps
module dev_tb;
    logic clk=0, areset=0, bump_left=0, bump_right=0, ground=1, dig=0;
    wire walk_left, walk_right, aaah, digging;
    integer mode=0;
    bit rightward=0;
    integer checks=0;
    TopModule dut(.*);
    always #5 clk=~clk;
    initial begin
        #20000;
        $fatal(1, "TIMEOUT");
    end
    task automatic check_outputs;
        reg [3:0] expected;
        begin
            expected = {mode==0 && !rightward, mode==0 && rightward,
                        mode==1, mode==2};
            if ({walk_left,walk_right,aaah,digging} !== expected)
                $fatal(1,"Mismatch mode=%0d direction=%0d actual=%b expected=%b",
                       mode,rightward,{walk_left,walk_right,aaah,digging},expected);
            checks=checks+1;
        end
    endtask
    task automatic reset_machine;
        begin
            @(negedge clk);
            #1 areset=1;
            mode=0; rightward=0;
            #1; check_outputs();
            #1 areset=0;
        end
    endtask
    task automatic step(input bit g, input bit d, input bit bl, input bit br);
        begin
            @(negedge clk);
            ground=g; dig=d; bump_left=bl; bump_right=br;
            #1; check_outputs(); // Moore outputs do not follow input changes.
            @(posedge clk);
            case(mode)
                0: begin
                    if (!g) mode=1;
                    else if (d) mode=2;
                    else if ((!rightward && bl) || (rightward && br))
                        rightward=!rightward;
                end
                1: if(g) mode=0;
                2: if(!g) mode=1;
            endcase
            #1; check_outputs();
        end
    endtask
    integer state_index, input_index, iteration;
    initial begin
        for (state_index=0;state_index<6;state_index=state_index+1) begin
            for (input_index=0;input_index<16;input_index=input_index+1) begin
                reset_machine();
                if (state_index%2) step(1,0,1,0);
                if (state_index/2==1) step(0,0,0,0);
                if (state_index/2==2) step(1,1,0,0);
                step(input_index[3],input_index[2],input_index[1],input_index[0]);
            end
        end
        for(iteration=0;iteration<500;iteration=iteration+1) begin
            step($random,$random,$random,$random);
            if(iteration%37==0) reset_machine();
        end
        $display("PASS: %0d output checks; all 96 state/input transitions and randomized sequences",checks);
        $finish;
    end
endmodule
