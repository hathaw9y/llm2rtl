`timescale 1ns/1ps
module dev_tb;
    logic clk=0, areset=0, predict_valid=0, predict_taken=0;
    logic train_mispredicted=0, train_taken=0;
    logic [31:0] train_history=0;
    wire [31:0] predict_history;
    bit expected[0:31];
    integer checks=0;
    integer seed=118;
    TopModule dut(.*);
    always #5 clk=~clk;
    task automatic check;
        for (integer j=0; j<32; j=j+1)
            if (predict_history[j] !== expected[j])
                $fatal(1,"Mismatch check=%0d bit=%0d got=%h",checks,j,predict_history);
        checks=checks+1;
    endtask
    always @(posedge clk or posedge areset) begin
        if (areset)
            for (integer j=0;j<32;j=j+1) expected[j]=0;
        else if (train_mispredicted) begin
            for (integer j=31;j>0;j=j-1) expected[j]=train_history[j-1];
            expected[0]=train_taken;
        end else if (predict_valid) begin
            for (integer j=31;j>0;j=j-1) expected[j]=expected[j-1];
            expected[0]=predict_taken;
        end
        #1; check();
    end
    task automatic cycle(input bit pv,pt,tm,tt,input logic [31:0] th);
        @(negedge clk);
        predict_valid=pv; predict_taken=pt;
        train_mispredicted=tm; train_taken=tt; train_history=th;
        #1; check(); // Input changes alone must not alter state.
        @(posedge clk); #2;
    endtask
    initial begin
        #2; areset=1;
        #2; check();
        @(negedge clk); areset=0;
        #1; check();
        cycle(1,1,0,0,0);
        cycle(1,0,0,0,0);
        cycle(0,1,0,1,32'hffffffff);
        cycle(0,0,1,1,32'h80000000);
        cycle(1,0,1,1,32'ha5a5a5a5);
        cycle(1,1,1,0,32'hffffffff);
        cycle(0,0,1,0,0);
        cycle(1,1,0,0,0);
        repeat(33) cycle(1,0,0,0,0);
        repeat(33) cycle(1,1,0,0,0);
        for (integer n=0;n<1000;n=n+1)
            cycle($random(seed),$random(seed),$random(seed),$random(seed),$random(seed));
        @(negedge clk); #2; areset=1;
        #2; check();
        @(negedge clk); areset=0; predict_valid=0; train_mispredicted=0;
        #1; check();
        cycle(0,1,0,1,32'hffffffff);
        cycle(1,1,0,0,0);
        $display("PASS: %0d comparisons, directed and 1000 randomized cycles",checks);
        $finish;
    end
    initial begin
        #20000; $fatal(1,"Watchdog timeout");
    end
endmodule
