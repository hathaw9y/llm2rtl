`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg in = 0;
    wire disc, flag, err;
    TopModule dut (.clk(clk), .reset(reset), .in(in),
                   .disc(disc), .flag(flag), .err(err));
    always #5 clk = ~clk;

    integer run_length = 0;
    integer samples = 0;
    reg [2:0] expected = 0;
    reg valid = 0;
    integer n, j, trial;
    reg [31:0] rng = 32'h81f30ab7;

    task check_outputs;
        begin
            if ({disc, flag, err} !== expected)
                $fatal(1, "Mismatch at time %0t sample %0d: got %b expected %b run %0d",
                       $time, samples, {disc, flag, err}, expected, run_length);
        end
    endtask

    task sample_bit(input reg bit_value, input reg reset_value);
        begin
            @(negedge clk);
            in = bit_value;
            reset = reset_value;
            #1;
            // Inputs and reset must have no asynchronous effect on Moore outputs.
            if (valid) check_outputs();
            @(posedge clk);
            expected = 3'b000;
            if (reset_value) run_length = 0;
            else if (bit_value) begin
                run_length = run_length + 1;
                if (run_length >= 7) expected[0] = 1;
            end else begin
                if (run_length == 5) expected[2] = 1;
                if (run_length == 6) expected[1] = 1;
                run_length = 0;
            end
            samples = samples + 1;
            valid = 1;
            #1;
            check_outputs();
            #3;
            check_outputs();
        end
    endtask

    initial begin
        // Original problem does not constrain power-up values before reset.
        sample_bit(1, 1);
        sample_bit(0, 0);
        for (n = 0; n <= 20; n = n + 1) begin
            sample_bit(0, 0);
            for (j = 0; j < n; j = j + 1) sample_bit(1, 0);
            sample_bit(0, 0);
            sample_bit(0, 0);
        end
        // Completing zeros are shared with following patterns.
        for (trial = 0; trial < 8; trial = trial + 1) begin
            for (j = 0; j < 5; j = j + 1) sample_bit(1, 0);
            sample_bit(0, 0);
            for (j = 0; j < 6; j = j + 1) sample_bit(1, 0);
            sample_bit(0, 0);
        end
        // Reset every partial-run boundary, the error state, and event states.
        for (n = 0; n <= 10; n = n + 1) begin
            for (j = 0; j < n; j = j + 1) sample_bit(1, 0);
            sample_bit(1, 1);
            sample_bit(0, 0);
        end
        for (n = 5; n <= 6; n = n + 1) begin
            for (j = 0; j < n; j = j + 1) sample_bit(1, 0);
            sample_bit(0, 0);
            sample_bit(1, 1);
            sample_bit(1, 1);
            sample_bit(0, 0);
        end
        for (trial = 0; trial < 3000; trial = trial + 1) begin
            rng = {rng[30:0], rng[31] ^ rng[21] ^ rng[1] ^ rng[0]};
            sample_bit(rng[0], (trial % 97 == 0));
        end
        $display("PASS: HDLC patterns, output phases, synchronous reset, and random stream (%0d samples)", samples);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
