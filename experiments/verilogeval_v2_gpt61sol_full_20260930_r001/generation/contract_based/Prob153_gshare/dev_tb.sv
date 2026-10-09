`timescale 1ns/1ps
module dev_tb;
    logic clk=0, areset=0;
    logic predict_valid=0, train_valid=0, train_taken=0, train_mispredicted=0;
    logic [6:0] predict_pc=0, train_history=0, train_pc=0;
    wire predict_taken;
    wire [6:0] predict_history;
    TopModule dut(.*);
    integer counters [0:127];
    integer history_model=0, checks=0, cycles=0;
    integer seed=32'h153abc, random_word;
    integer idx, j;
    integer old_prediction, training_index;
    always #5 clk=~clk;

    task automatic compare_outputs;
        integer expected;
        begin
            expected = (counters[(predict_pc ^ history_model) & 127] >= 2);
            checks=checks+1;
            if (predict_history !== history_model[6:0] || predict_taken !== (expected != 0))
                $fatal(1, "Mismatch cycle=%0d pc=%0d history=%0d got_history=%0d expected_taken=%0d got_taken=%b", cycles,predict_pc,history_model,predict_history,expected,predict_taken);
        end
    endtask

    task automatic reset_now;
        begin
            // Assert away from an active edge and check without waiting for clk.
            @(negedge clk); #2;
            areset=1;
            history_model=0;
            for (integer n=0;n<128;n=n+1) counters[n]=1;
            #1; compare_outputs();
            @(negedge clk); #1; areset=0;
        end
    endtask

    task automatic step(input bit pv, input integer pc, input bit tv,
                        input bit taken, input bit mispred, input integer th,
                        input integer tpc);
        begin
            @(negedge clk);
            predict_valid=pv; predict_pc=pc;
            train_valid=tv; train_taken=taken; train_mispredicted=mispred;
            train_history=th; train_pc=tpc;
            #1; compare_outputs();
            old_prediction=(counters[(pc ^ history_model) & 127]>=2);
            training_index=(tpc ^ th) & 127;
            @(posedge clk);
            if (tv) begin
                if (taken && counters[training_index]<3) counters[training_index]=counters[training_index]+1;
                if (!taken && counters[training_index]>0) counters[training_index]=counters[training_index]-1;
            end
            if (tv && mispred) history_model=((th*2)+taken)&127;
            else if (pv) history_model=((history_model*2)+old_prediction)&127;
            cycles=cycles+1;
            #1; compare_outputs();
        end
    endtask

    initial begin
        reset_now();
        for (idx=0;idx<128;idx=idx+1) begin
            step(0,idx,0,0,0,0,0);
            for(j=0;j<5;j=j+1) step(0,idx,1,1,0,0,idx);
            for(j=0;j<5;j=j+1) step(0,idx,1,0,0,0,idx);
        end
        // Same-entry prediction sees weakly not-taken before taken training.
        reset_now();
        step(1,0,1,1,0,0,0);
        step(1,0,0,0,0,0,0);
        // Recovery wins over speculative prediction and uses supplied history.
        step(1,7,1,1,1,7'h55,7'h7f);
        step(1,4,0,0,1,7'h7f,0);
        step(0,9,1,0,0,7'h7f,7'h7f);
        step(0,0,0,1,1,7'h55,1);
        for (idx=0;idx<5000;idx=idx+1) begin
            random_word=$random(seed);
            step(random_word & 1, (random_word >> 1)&127,
                 (random_word >> 8)&1, (random_word >> 9)&1,
                 (random_word >> 10)&1, (random_word >> 11)&127,
                 (random_word >> 18)&127);
            if(idx==2499) reset_now();
        end
        predict_valid=0; train_valid=0;
        reset_now();
        for(idx=0;idx<128;idx=idx+1) step(0,idx,0,0,0,0,0);
        $display("PASS cycles=%0d output_checks=%0d all_entries_and_randomized_traffic",cycles,checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1,"Development simulation timeout");
    end
endmodule
