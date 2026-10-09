`timescale 1ns/1ps
module dev_tb;
    logic clk=0;
    logic shift_ena=0, count_ena=0, data=0;
    wire [3:0] q;
    integer expected=0;
    integer checks=0;
    integer word_value, bit_index, iteration;
    logic [3:0] prior;
    TopModule dut (.clk(clk), .shift_ena(shift_ena),
                   .count_ena(count_ena), .data(data), .q(q));
    always #5 clk=~clk;
    initial begin
        #100000;
        $fatal(1,"FAIL: watchdog timeout");
    end
    task automatic step(input logic s, input logic c, input logic d,
                        input logic known);
        begin
            @(negedge clk);
            prior=q;
            shift_ena=s; count_ena=c; data=d;
            #1;
            if (q !== prior) $fatal(1,"FAIL: update without positive edge");
            if (s) expected=(expected*2+d)%16;
            else if (c) expected=(expected+15)%16;
            @(posedge clk);
            #1;
            if (known) begin
                checks=checks+1;
                if (q !== expected[3:0])
                    $fatal(1,"FAIL: s=%b c=%b d=%b expected=%d actual=%b",s,c,d,expected,q);
            end
        end
    endtask
    initial begin
        // Establish state through the public interface, without a reset.
        step(1,0,0,0); step(1,0,0,0);
        step(1,0,0,0); step(1,0,0,1);
        for (word_value=0; word_value<16; word_value=word_value+1) begin
            for (bit_index=3; bit_index>=0; bit_index=bit_index-1)
                step(1,0,(word_value>>bit_index)&1,1);
            if (q !== word_value[3:0]) $fatal(1,"FAIL: MSB-first load");
            step(0,0,1,1);
            for (iteration=0; iteration<17; iteration=iteration+1)
                step(0,1,iteration%2,1);
        end
        for (iteration=0; iteration<300; iteration=iteration+1) begin
            case (iteration%3)
                0: step(1,0,((iteration*7+iteration/3)%2),1);
                1: step(0,1,iteration%2,1);
                2: step(0,0,iteration%2,1);
            endcase
        end
        $display("PASS: %0d checked cycles; all loads, decrement states, wraparound, holds and mixed operations",checks);
        $finish;
    end
endmodule
