`timescale 1ns/1ps
module dev_tb;
    logic clk=0, reset=0, data=0, ack=0;
    wire [3:0] count;
    wire counting, done;
    TopModule dut(.*);
    always #5 clk=~clk;
    task automatic tick(input logic d, input logic a, input logic r);
        @(negedge clk);
        data=d; ack=a; reset=r;
        @(posedge clk); #1;
    endtask
    task automatic idle_check;
        if (counting !== 0 || done !== 0) $fatal(1,"Expected search/load state");
    endtask
    task automatic start_timer(input integer delay_value);
        // Extra leading ones exercise overlapping pattern prefixes.
        tick(1,0,0); idle_check();
        tick(1,0,0); idle_check();
        tick(1,0,0); idle_check();
        tick(0,0,0); idle_check();
        tick(1,0,0); idle_check();
        for (integer b=3; b>=0; b=b-1) begin
            tick((delay_value >> b)&1,0,0);
            if (b>0) idle_check();
        end
        if (counting !== 1 || done !== 0 || count !== delay_value)
            $fatal(1,"Incorrect timer entry delay=%0d count=%0d",delay_value,count);
    endtask
    task automatic finish_timer(input integer delay_value);
        for (integer c=0; c<(delay_value+1)*1000; c=c+1) begin
            if (counting !== 1 || done !== 0 || count !== (delay_value-c/1000))
                $fatal(1,"Cycle mismatch delay=%0d cycle=%0d count=%0d",delay_value,c,count);
            // Both data and ack are irrelevant while counting.
            tick(c%2,c%3==0,0);
        end
        if (counting !== 0 || done !== 1) $fatal(1,"Missing completion");
        repeat (8) begin
            tick(1,0,0);
            if (counting !== 0 || done !== 1) $fatal(1,"Done did not hold");
        end
        tick(1,1,0); idle_check();
        // The data on the acknowledgement edge must not seed a new prefix.
        tick(1,0,0); idle_check();
        tick(0,0,0); idle_check();
        tick(1,0,0); idle_check();
        tick(0,0,0); idle_check();
    endtask
    initial begin
        tick(0,0,1); idle_check();
        for (integer d=0; d<16; d=d+1) begin
            start_timer(d);
            finish_timer(d);
        end
        // Reset during counting, loading, and completion wait.
        start_timer(15);
        repeat (1010) tick(0,0,0);
        tick(1,1,1); idle_check();
        tick(1,0,0); tick(1,0,0); tick(0,0,0); tick(1,0,0);
        tick(1,0,0); tick(0,0,1); idle_check();
        start_timer(0);
        repeat (1000) tick(0,0,0);
        if (!done) $fatal(1,"Expected done before reset");
        tick(0,0,1); idle_check();
        start_timer(1); finish_timer(1);
        $display("PASS: all 16 delays, exact cycle counts, overlap, ignored inputs, acknowledgement, and resets");
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1,"Development test timeout");
    end
endmodule
