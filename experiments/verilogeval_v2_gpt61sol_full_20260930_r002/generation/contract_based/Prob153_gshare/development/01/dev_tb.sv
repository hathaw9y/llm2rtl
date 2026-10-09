`timescale 1ns/1ps
module dev_tb;
    logic clk=0, areset=0;
    logic predict_valid=0, train_valid=0, train_taken=0, train_mispredicted=0;
    logic [6:0] predict_pc=0, train_pc=0, train_history=0;
    wire predict_taken;
    wire [6:0] predict_history;
    TopModule dut(.*);
    always #5 clk=~clk;
    integer counters[0:127];
    integer hist, cycles=0;
    integer k, j, idx;
    reg [31:0] rng=32'h273ab195;

    task automatic compare_outputs;
        integer expected_direction;
        begin
            if (predict_history !== hist[6:0])
                $fatal(1,"history cycle %0d got %0d expected %0d",cycles,predict_history,hist);
            expected_direction = (counters[predict_pc ^ hist] >= 2);
            if (predict_valid && predict_taken !== expected_direction[0])
                $fatal(1,"direction cycle %0d pc %0d hist %0d got %b expected %0d",
                    cycles,predict_pc,hist,predict_taken,expected_direction);
        end
    endtask

    task automatic reset_now;
        integer n;
        begin
            // Assert between clock edges, and check before the next edge.
            @(negedge clk);
            #2 areset=1;
            hist=0;
            for(n=0;n<128;n=n+1) counters[n]=1;
            #1 compare_outputs();
            @(negedge clk);
            #1 areset=0;
        end
    endtask

    task automatic step(input bit pv, input integer pc,
                        input bit tv, input bit taken, input bit missed,
                        input integer th, input integer tpc);
        integer old_direction, next_hist, ti;
        begin
            @(negedge clk);
            predict_valid=pv; predict_pc=pc;
            train_valid=tv; train_taken=taken; train_mispredicted=missed;
            train_history=th; train_pc=tpc;
            #1 compare_outputs();
            // Capture prediction before the edge: training must not bypass.
            old_direction=(counters[pc ^ hist]>=2);
            next_hist=hist;
            if(tv && missed) next_hist=(th*2+int'(taken))%128;
            else if(pv) next_hist=(hist*2+old_direction)%128;
            ti=tpc ^ th;
            @(posedge clk);
            if(tv) begin
                if(taken && counters[ti]<3) counters[ti]=counters[ti]+1;
                if(!taken && counters[ti]>0) counters[ti]=counters[ti]-1;
            end
            hist=next_hist;
            cycles=cycles+1;
            #1 compare_outputs();
        end
    endtask

    initial begin
        #200000;
        $fatal(1,"bounded timeout");
    end

    initial begin
        reset_now();
        // Train and observe every entry, saturating upward and downward.
        for(k=0;k<128;k=k+1) begin
            for(j=0;j<4;j=j+1) step(0,0,1,1,0,0,k);
            step(1,k ^ hist,0,0,0,0,0);
            for(j=0;j<5;j=j+1) step(0,0,1,0,0,0,k);
            step(1,k ^ hist,0,0,0,0,0);
        end
        reset_now();
        // Counter 01 -> 10 collision: current prediction must be not taken.
        step(1,0,1,1,0,0,0);
        step(1,0,1,0,0,0,0);
        // Recovery overrides younger prediction, including high history bits.
        step(1,127,1,1,1,7'h65,7'h17);
        step(1,23,1,0,1,7'h7f,7'h7f);
        // Misprediction alone with invalid training must not roll back.
        step(0,0,0,1,1,7'h12,0);
        step(1,64,0,0,1,7'h12,0);
        // Valid non-mispredict training must not overwrite speculative history.
        step(1,77,1,1,0,7'h55,7'h2a);
        for(k=0;k<1500;k=k+1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            step(rng[0],rng[7:1],rng[8],rng[9],rng[10],rng[17:11],rng[24:18]);
        end
        reset_now();
        // Every reset PHT entry must return to not taken.
        for(k=0;k<128;k=k+1) step(1,k,0,0,0,0,0);
        $display("PASS gshare independent oracle: %0d cycles",cycles);
        $finish;
    end
endmodule
