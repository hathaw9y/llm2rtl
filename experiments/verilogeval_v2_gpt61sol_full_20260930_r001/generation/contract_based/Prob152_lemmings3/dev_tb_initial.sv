`timescale 1ns/1ps
module dev_tb;
    logic clk=0, areset=0, bump_left=0, bump_right=0, ground=1, dig=0;
    wire walk_left, walk_right, aaah, digging;
    TopModule dut(.*);
    always #5 clk=~clk;
    integer mode=0; // 0 walking, 1 falling, 2 digging
    bit rightward=0;
    integer comparisons=0;
    integer coverage[0:5][0:15];
    integer s, v, k, old_state;
    logic [3:0] expected;

    task automatic check_outputs;
        begin
            expected=4'b0000;
            if (mode==0) expected=rightward ? 4'b0100 : 4'b1000;
            else if (mode==1) expected=4'b0010;
            else expected=4'b0001;
            if ({walk_left,walk_right,aaah,digging} !== expected)
                $fatal(1,"Mismatch mode=%0d right=%0d controls=%b actual=%b expected=%b",mode,rightward,{bump_left,bump_right,ground,dig},{walk_left,walk_right,aaah,digging},expected);
            comparisons=comparisons+1;
        end
    endtask

    task automatic reset_machine;
        begin
            @(negedge clk);
            #1 areset=1;
            mode=0; rightward=0;
            #1 check_outputs(); // away from clock edge
            @(posedge clk); #1 check_outputs();
            @(negedge clk); #1 areset=0;
            #1 check_outputs();
        end
    endtask

    task automatic step(input logic bl, br, g, d);
        begin
            @(negedge clk);
            bump_left=bl; bump_right=br; ground=g; dig=d;
            #1 check_outputs(); // Moore outputs must not follow controls
            old_state=mode*2+integer'(rightward);
            coverage[old_state][{bl,br,g,d}]=coverage[old_state][{bl,br,g,d}]+1;
            @(posedge clk);
            if (mode==0) begin
                if (!g) mode=1;
                else if (d) mode=2;
                else if ((!rightward && bl) || (rightward && br)) rightward=!rightward;
            end else if (mode==1) begin
                if (g) mode=0;
            end else if (!g) mode=1;
            #1 check_outputs();
        end
    endtask

    task automatic reach(input integer target);
        begin
            reset_machine();
            if (target%2==1) step(1,0,1,0);
            if (target/2==1) step(0,0,0,0);
            if (target/2==2) step(0,0,1,1);
        end
    endtask

    initial begin
        for (s=0;s<6;s=s+1)
            for (v=0;v<16;v=v+1) coverage[s][v]=0;
        for (s=0;s<6;s=s+1) begin
            for (v=0;v<16;v=v+1) begin
                reach(s);
                step(v[3],v[2],v[1],v[0]);
            end
            reach(s);
            reset_machine();
        end
        // Continuous sequences verify persistent direction and mode history.
        for (k=0;k<1000;k=k+1) begin
            v=$urandom_range(0,15);
            step(v[3],v[2],v[1],v[0]);
        end
        for (s=0;s<6;s=s+1)
            for (v=0;v<16;v=v+1)
                if (coverage[s][v]==0) $fatal(1,"Missing transition coverage %0d %0d",s,v);
        $display("PASS: %0d comparisons; all 96 state/input combinations covered",comparisons);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"Development test timeout");
    end
endmodule
