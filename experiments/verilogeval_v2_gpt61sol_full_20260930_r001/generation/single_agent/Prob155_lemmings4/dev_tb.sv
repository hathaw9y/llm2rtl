`timescale 1ns/1ps
module dev_tb;
    logic clk=0, areset=0, bump_left=0, bump_right=0, ground=1, dig=0;
    wire walk_left, walk_right, aaah, digging;
    TopModule dut(.*);
    always #5 clk=~clk;
    integer checks=0;
    task automatic expect_outputs(input logic [3:0] expected);
        begin
            checks=checks+1;
            if ({walk_left,walk_right,aaah,digging} !== expected)
                $fatal(1,"check %0d: expected %b got %b",checks,expected,
                    {walk_left,walk_right,aaah,digging});
        end
    endtask
    task automatic reset_dut;
        begin
            @(negedge clk);
            areset=1; ground=1; dig=0; bump_left=0; bump_right=0;
            #1; expect_outputs(4'b1000);
            @(negedge clk); areset=0;
        end
    endtask
    task automatic step(input logic g,d,bl,br,input logic [3:0] expected);
        begin
            @(negedge clk); ground=g; dig=d; bump_left=bl; bump_right=br;
            @(posedge clk); #1; expect_outputs(expected);
        end
    endtask
    task automatic fall_test(input integer length, input logic fatal_fall);
        integer i;
        begin
            reset_dut();
            for(i=0;i<length;i=i+1) step(0,1,1,1,4'b0010);
            step(1,1,1,1,fatal_fall ? 4'b0000 : 4'b1000);
            if(fatal_fall) begin
                repeat(4) step(1,1,1,1,4'b0000);
                step(0,0,0,0,4'b0000);
            end
        end
    endtask
    initial begin
        reset_dut();
        step(1,0,0,1,4'b1000);
        step(1,0,1,1,4'b0100);
        step(1,0,1,0,4'b0100);
        step(1,0,1,1,4'b1000);
        step(1,1,1,1,4'b0001);
        step(1,0,1,1,4'b0001);
        step(0,1,1,1,4'b0010);
        step(0,1,1,1,4'b0010);
        step(1,1,1,1,4'b1000);
        step(1,0,1,0,4'b0100);
        step(1,1,0,1,4'b0001);
        step(0,1,1,1,4'b0010);
        step(1,1,1,1,4'b0100);
        step(0,1,1,1,4'b0010);
        reset_dut();
        fall_test(1,0);
        fall_test(19,0);
        fall_test(20,0);
        fall_test(21,1);
        fall_test(22,1);
        fall_test(1000,1);
        reset_dut();
        step(0,0,0,0,4'b0010);
        step(1,0,0,0,4'b1000);
        step(0,0,0,0,4'b0010);
        step(1,0,0,0,4'b1000);
        $display("PASS: %0d self-checking observations",checks);
        $finish;
    end
    initial begin
        #200000; $fatal(1,"development simulation timeout");
    end
endmodule
