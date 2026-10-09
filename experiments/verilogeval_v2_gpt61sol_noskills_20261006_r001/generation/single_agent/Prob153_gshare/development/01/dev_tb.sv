`timescale 1ns/1ps
module dev_tb;
    reg clk=0, areset=0;
    reg predict_valid=0, train_valid=0, train_taken=0, train_mispredicted=0;
    reg [6:0] predict_pc=0, train_history=0, train_pc=0;
    wire predict_taken;
    wire [6:0] predict_history;
    TopModule dut(.*);
    always #5 clk=~clk;
    integer counts[0:127];
    integer hist;
    integer cycles=0;
    integer i, j, idx, next_hist, old_prediction;
    reg [31:0] rng=32'h153a927b;

    task check_outputs;
        integer address;
        begin
            address = predict_pc ^ hist;
            if (predict_history !== hist[6:0])
                $fatal(1,"history mismatch cycle %0d got %0h expected %0h",cycles,predict_history,hist);
            if (predict_taken !== (counts[address] >= 2))
                $fatal(1,"prediction mismatch cycle %0d entry %0d count %0d",cycles,address,counts[address]);
        end
    endtask

    task step(input reg pv, input reg [6:0] pc,
              input reg tv, input reg taken, input reg mis,
              input reg [6:0] th, input reg [6:0] tpc);
        begin
            @(negedge clk);
            predict_valid=pv; predict_pc=pc;
            train_valid=tv; train_taken=taken; train_mispredicted=mis;
            train_history=th; train_pc=tpc;
            #1;
            check_outputs();
            old_prediction=(counts[pc ^ hist] >= 2);
            next_hist=hist;
            if (tv && mis) next_hist=((th*2)+taken)%128;
            else if (pv) next_hist=((hist*2)+old_prediction)%128;
            @(posedge clk);
            if (tv) begin
                idx=tpc ^ th;
                if (taken && counts[idx]<3) counts[idx]=counts[idx]+1;
                else if (!taken && counts[idx]>0) counts[idx]=counts[idx]-1;
            end
            hist=next_hist;
            cycles=cycles+1;
            #1;
            check_outputs();
        end
    endtask

    task reset_async;
        begin
            @(negedge clk);
            #2; areset=1;
            hist=0;
            for (j=0;j<128;j=j+1) counts[j]=1;
            #1; check_outputs();
            @(posedge clk); #1; check_outputs();
            #1; areset=0;
        end
    endtask

    initial begin
        // No initial-state assumption before the first asynchronous reset.
        reset_async();
        // Sweep every table entry through both saturation boundaries.
        for (i=0;i<128;i=i+1) begin
            step(0,i,1,1,0,0,i);
            step(0,i,1,1,0,0,i);
            step(0,i,1,1,0,0,i);
            step(0,i,1,0,0,0,i);
            step(0,i,1,0,0,0,i);
            step(0,i,1,0,0,0,i);
            step(0,i,1,0,0,0,i);
        end
        reset_async();
        // Same-entry prediction uses the pre-edge counter; subsequent history
        // reflects that prediction even when training crosses the threshold.
        step(1,0,1,1,0,0,0);
        step(1,0,1,0,0,0,0);
        // Recovery wins over speculation and uses supplied older history.
        step(1,7'h7f,1,1,1,7'h65,7'h32);
        step(0,7'h22,0,0,1,7'h7f,0);
        step(1,7'h1a,1,0,0,7'h55,7'h2a);
        step(1,7'h05,1,0,1,7'h7f,7'h7f);
        for (i=0;i<2500;i=i+1) begin
            rng=rng ^ (rng << 13);
            rng=rng ^ (rng >> 17);
            rng=rng ^ (rng << 5);
            step(rng[0],rng[7:1],rng[8],rng[9],rng[10],rng[17:11],rng[24:18]);
        end
        // Reset while request inputs are active, then verify all entries again.
        predict_valid=1; train_valid=1; train_mispredicted=1;
        reset_async();
        for (i=0;i<128;i=i+1) step(0,i,0,0,0,0,0);
        $display("PASS gshare directed and randomized checks (%0d cycles)",cycles);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"bounded timeout");
    end
endmodule
