`timescale 1ns/1ps
module dev_tb;
    reg clk=0, areset=0;
    reg predict_valid=0, train_valid=0, train_taken=0, train_mispredicted=0;
    reg [6:0] predict_pc=0, train_pc=0, train_history=0;
    wire predict_taken;
    wire [6:0] predict_history;
    TopModule dut(.*);
    integer counters[0:127];
    integer hist, cycles=0;
    integer idx, j, k, seed=32'h153ab987;
    reg old_prediction;
    integer next_hist, train_idx;
    task check_outputs;
        begin
            if (predict_history !== hist[6:0])
                $fatal(1,"History mismatch cycle %0d expected %0d got %0d",cycles,hist,predict_history);
            if (predict_taken !== (counters[predict_pc ^ hist] >= 2))
                $fatal(1,"Direction mismatch cycle %0d index %0d counter %0d got %b",
                       cycles,predict_pc ^ hist,counters[predict_pc ^ hist],predict_taken);
        end
    endtask
    task reset_async;
        begin
            clk=0;
            #2;
            areset=1;
            hist=0;
            for (integer n=0;n<128;n=n+1) counters[n]=1;
            #1;
            check_outputs();
            // Reset held over an edge also takes precedence over requests.
            clk=1;
            #1; check_outputs();
            clk=0;
            #1; areset=0;
            #1; check_outputs();
        end
    endtask
    task step;
        begin
            clk=0;
            #2;
            check_outputs();
            old_prediction=(counters[predict_pc ^ hist] >= 2);
            next_hist=hist;
            if (train_valid && train_mispredicted)
                next_hist=((train_history * 2) + train_taken) % 128;
            else if (predict_valid)
                next_hist=((hist * 2) + old_prediction) % 128;
            train_idx=train_pc ^ train_history;
            // Check again just before edge: training must not bypass the table.
            #1; check_outputs();
            clk=1;
            if (train_valid) begin
                if (train_taken && counters[train_idx]<3)
                    counters[train_idx]=counters[train_idx]+1;
                else if (!train_taken && counters[train_idx]>0)
                    counters[train_idx]=counters[train_idx]-1;
            end
            hist=next_hist;
            cycles=cycles+1;
            #1; check_outputs();
            clk=0;
            #1;
        end
    endtask
    initial begin
        // Original specifies no power-on state before asynchronous reset.
        #1;
        if (predict_history !== 7'bxxxxxxx || predict_taken !== 1'bx)
            $fatal(1,"Unexpected initialization before reset");
        reset_async();
        // Every entry: reset value, both endpoints, both threshold crossings,
        // and XOR training using nonzero supplied history.
        for (j=0;j<128;j=j+1) begin
            predict_valid=0; train_mispredicted=0;
            predict_pc=j ^ hist;
            train_history=(j*37+19)%128;
            train_pc=j ^ train_history;
            train_valid=1; train_taken=1;
            for(k=0;k<4;k=k+1) step();
            train_taken=0;
            for(k=0;k<5;k=k+1) step();
            train_taken=1;
            for(k=0;k<2;k=k+1) step();
        end
        // Same-entry crossing: speculative shift uses pre-training prediction.
        reset_async();
        predict_valid=1; train_valid=1; train_taken=1;
        train_mispredicted=0; train_history=0; train_pc=0; predict_pc=0;
        step();
        // Recovery wins over prediction and discards oldest history bit.
        train_history=7'b1101011; train_pc=7'd72;
        train_mispredicted=1; train_taken=0; predict_pc=7'd41;
        step();
        train_taken=1; step();
        // train_mispredicted without train_valid cannot change history.
        train_valid=0; predict_valid=0; train_history=0;
        step();
        // Multiple predictions exercise shift length and all history bits.
        train_mispredicted=0;
        for(j=0;j<20;j=j+1) begin
            predict_valid=1; predict_pc=j;
            step();
        end
        for(j=0;j<2000;j=j+1) begin
            predict_valid=$random(seed);
            train_valid=$random(seed);
            train_taken=$random(seed);
            train_mispredicted=$random(seed);
            predict_pc=$random(seed);
            train_pc=$random(seed);
            train_history=$random(seed);
            if (j%7==0) train_pc=predict_pc ^ hist ^ train_history;
            step();
            if(j%251==0) reset_async();
        end
        $display("PASS: gshare directed and randomized checks (%0d cycles)",cycles);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"Timeout");
    end
endmodule
