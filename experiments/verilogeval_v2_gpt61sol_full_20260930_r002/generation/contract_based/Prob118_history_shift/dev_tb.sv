`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic predict_valid = 0;
    logic predict_taken = 0;
    logic train_mispredicted = 0;
    logic train_taken = 0;
    logic [31:0] train_history = 0;
    wire [31:0] predict_history;
    logic [31:0] expected;
    logic model_valid = 0;
    logic [31:0] rng = 32'h92173abc;
    integer checks = 0;
    integer i;
    TopModule dut (.*);
    always #5 clk = ~clk;

    task automatic check_output;
        if (model_valid) begin
            checks = checks + 1;
            if (predict_history !== expected)
                $fatal(1, "history mismatch at %0t: got %h expected %h", $time, predict_history, expected);
        end
    endtask

    // Independent per-bit model: old younger bit becomes next older bit.
    always @(posedge clk or posedge areset) begin
        if (areset) begin
            expected = 32'b0;
            model_valid = 1;
        end else if (train_mispredicted) begin
            for (integer b = 31; b > 0; b = b - 1)
                expected[b] = train_history[b-1];
            expected[0] = train_taken;
        end else if (predict_valid) begin
            for (integer b = 31; b > 0; b = b - 1)
                expected[b] = expected[b-1];
            expected[0] = predict_taken;
        end
        #1;
        check_output();
    end

    task automatic cycle(input logic pv, pt, tm, tt, input logic [31:0] th);
        @(negedge clk);
        predict_valid = pv;
        predict_taken = pt;
        train_mispredicted = tm;
        train_taken = tt;
        train_history = th;
        #1;
        check_output(); // Inputs alone must not change stored history.
        @(posedge clk);
        #2;
        check_output();
    endtask

    initial begin
        // Establish state asynchronously at t=2, before the first clock edge.
        #2 areset = 1;
        #2 check_output();
        predict_valid = 1;
        train_mispredicted = 1;
        train_history = 32'hffffffff;
        train_taken = 1;
        @(posedge clk);
        #2 check_output();
        #1 areset = 0;
        #1 check_output();
        cycle(0, 0, 0, 0, 32'hffffffff);
        cycle(1, 1, 0, 0, 0);
        cycle(1, 0, 0, 0, 0);
        for (i = 0; i < 34; i = i + 1)
            cycle(1, 1, 0, 0, 0);
        for (i = 0; i < 33; i = i + 1)
            cycle(1, 0, 0, 0, 0);
        cycle(0, 0, 1, 1, 32'h80000000);
        cycle(0, 0, 1, 0, 32'hffffffff);
        cycle(1, 1, 1, 0, 32'h12345678);
        cycle(1, 0, 1, 1, 32'h87654321);
        cycle(0, 1, 0, 1, 32'h0);
        // Reset a nonzero history between edges with both update controls high.
        @(negedge clk);
        #2 areset = 1;
        #1 check_output();
        @(posedge clk);
        #2 check_output();
        areset = 0;
        #1 check_output();
        for (i = 0; i < 256; i = i + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            cycle(rng[0], rng[1], rng[2], rng[3], rng);
        end
        cycle(0, 0, 0, 0, 0);
        $display("PASS history shift: %0d comparisons", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "timeout");
    end
endmodule
