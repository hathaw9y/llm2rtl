`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg areset = 0;
    reg predict_valid = 0;
    reg [6:0] predict_pc = 0;
    wire predict_taken;
    wire [6:0] predict_history;
    reg train_valid = 0;
    reg train_taken = 0;
    reg train_mispredicted = 0;
    reg [6:0] train_history = 0;
    reg [6:0] train_pc = 0;
    TopModule dut (.*);

    integer counters [0:127];
    integer history;
    integer cycles = 0;
    integer idx, k, j;
    reg old_prediction;

    task reset_model;
        integer n;
        begin
            history = 0;
            for (n=0; n<128; n=n+1) counters[n] = 1;
        end
    endtask

    task check_outputs;
        reg expected;
        begin
            expected = counters[predict_pc ^ history] >= 2;
            if (predict_history !== history[6:0])
                $fatal(1, "History mismatch cycle %0d expected %0d actual %0d", cycles, history, predict_history);
            if (predict_taken !== expected)
                $fatal(1, "Prediction mismatch cycle %0d index %0d expected %b actual %b", cycles, predict_pc ^ history, expected, predict_taken);
        end
    endtask

    // Check the combinational prediction before the accepting edge, then
    // update the independent integer model and check after NBA settlement.
    task step(input reg pv, input reg [6:0] pc,
              input reg tv, input reg taken, input reg miss,
              input reg [6:0] th, input reg [6:0] tpc);
        integer target;
        integer next_history;
        begin
            @(negedge clk);
            predict_valid = pv; predict_pc = pc;
            train_valid = tv; train_taken = taken;
            train_mispredicted = miss; train_history = th; train_pc = tpc;
            #1;
            check_outputs;
            old_prediction = counters[pc ^ history] >= 2;
            target = tpc ^ th;
            next_history = history;
            if (tv && miss) next_history = ((th * 2) + taken) % 128;
            else if (pv) next_history = ((history * 2) + old_prediction) % 128;
            @(posedge clk);
            if (tv) begin
                if (taken && counters[target] < 3) counters[target] = counters[target] + 1;
                if (!taken && counters[target] > 0) counters[target] = counters[target] - 1;
            end
            history = next_history;
            cycles = cycles + 1;
            #1;
            check_outputs;
        end
    endtask

    task async_reset;
        begin
            @(negedge clk);
            predict_valid = 0;
            train_valid = 0;
            #2 areset = 1;
            reset_model;
            #1 check_outputs;
            // Reset is observed without waiting for a positive clock edge.
            #1 areset = 0;
        end
    endtask

    initial begin
        #100000;
        $fatal(1, "Timeout");
    end

    initial begin
        async_reset;
        // Read every reset entry; train each through both saturation limits.
        for (k=0; k<128; k=k+1) begin
            step(0, k[6:0], 0, 0, 0, 0, 0);
            for (j=0; j<5; j=j+1)
                step(0, k[6:0], 1, 1, 0, 7'h55, k[6:0] ^ 7'h55);
            for (j=0; j<5; j=j+1)
                step(0, k[6:0], 1, 0, 0, 7'h2a, k[6:0] ^ 7'h2a);
        end
        async_reset;
        // Same-entry read/write: history must use the old prediction (0),
        // while the post-edge counter becomes taken.
        step(1, 0, 1, 1, 0, 0, 0);
        step(1, 0, 0, 0, 0, 0, 0);
        // Recovery wins over speculative prediction, including truncation.
        step(1, 7'h7f, 1, 1, 1, 7'h65, 7'h32);
        step(1, 7'h20, 1, 0, 1, 7'h7f, 7'h55);
        // Mispredicted without train_valid must not recover history.
        step(0, 7'h30, 0, 1, 1, 7'h15, 7'h44);
        step(1, 7'h30, 0, 1, 1, 7'h15, 7'h44);
        // Seven-bit shifts, hashes, independent simultaneous requests.
        for (k=0; k<2500; k=k+1) begin
            step($random, $random, $random, $random, $random, $random, $random);
        end
        async_reset;
        for (k=0; k<128; k=k+1)
            step(0, k[6:0], 0, 0, 0, 0, 0);
        $display("PASS gshare directed and randomized checks (%0d cycles)", cycles);
        $finish;
    end
endmodule
