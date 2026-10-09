`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic areset = 0;
    logic predict_valid = 0, train_valid = 0;
    logic [6:0] predict_pc = 0, train_pc = 0, train_history = 0;
    logic train_taken = 0, train_mispredicted = 0;
    wire predict_taken;
    wire [6:0] predict_history;
    TopModule dut (.*);
    integer counters [0:127];
    logic [6:0] history = 0;
    integer checks = 0;
    integer idx;
    logic old_prediction;

    task automatic check_outputs;
        begin
            if (predict_history !== history)
                $fatal(1, "History mismatch: expected %h got %h", history, predict_history);
            if (predict_taken !== (counters[predict_pc ^ history] >= 2))
                $fatal(1, "Prediction mismatch at index %d", predict_pc ^ history);
            checks = checks + 1;
        end
    endtask

    task automatic reset_predictor;
        begin
            @(negedge clk);
            #1 areset = 1;
            history = 0;
            for (integer k = 0; k < 128; k = k + 1) counters[k] = 1;
            #1;
            check_outputs();
            @(negedge clk);
            areset = 0;
        end
    endtask

    task automatic cycle;
        begin
            #1;
            check_outputs();
            old_prediction = (counters[predict_pc ^ history] >= 2);
            @(posedge clk);
            if (train_valid) begin
                idx = train_pc ^ train_history;
                if (train_taken && counters[idx] < 3) counters[idx] = counters[idx] + 1;
                if (!train_taken && counters[idx] > 0) counters[idx] = counters[idx] - 1;
            end
            if (train_valid && train_mispredicted)
                history = ((train_history << 1) | train_taken);
            else if (predict_valid)
                history = ((history << 1) | old_prediction);
            #1;
            check_outputs();
            @(negedge clk);
        end
    endtask

    initial begin
        reset_predictor();
        // Exercise every entry through both saturation limits and threshold crossings.
        for (integer k = 0; k < 128; k = k + 1) begin
            predict_valid = 0;
            predict_pc = k;
            train_pc = k;
            train_history = 0;
            train_valid = 1;
            train_taken = 1;
            repeat (5) cycle();
            train_taken = 0;
            repeat (5) cycle();
        end
        // Same-entry prediction consumes the old counter state on a training edge.
        predict_pc = 0;
        train_pc = 0;
        train_taken = 1;
        predict_valid = 1;
        repeat (4) cycle();
        // Recovery wins over speculative history and uses the supplied history.
        train_history = 7'b1010110;
        train_taken = 1;
        train_mispredicted = 1;
        cycle();
        train_valid = 0;
        cycle();
        reset_predictor();
        for (integer k = 0; k < 3000; k = k + 1) begin
            predict_valid = $urandom_range(0, 1);
            predict_pc = $urandom_range(0, 127);
            train_valid = $urandom_range(0, 1);
            train_taken = $urandom_range(0, 1);
            train_mispredicted = $urandom_range(0, 1);
            train_history = $urandom_range(0, 127);
            train_pc = $urandom_range(0, 127);
            if (k % 4 == 0) train_pc = predict_pc ^ history ^ train_history;
            cycle();
        end
        $display("PASS: %0d output checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Development test timeout");
    end
endmodule
