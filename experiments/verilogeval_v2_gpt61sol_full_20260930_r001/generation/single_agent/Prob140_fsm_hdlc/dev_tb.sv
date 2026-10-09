`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic in = 0;
    wire disc, flag, err;
    integer ones = 0;
    integer checks = 0;
    integer pattern, bit_index, run_length, k;
    logic expected_disc, expected_flag, expected_err;
    TopModule dut (.clk(clk), .reset(reset), .in(in),
                   .disc(disc), .flag(flag), .err(err));
    always #5 clk = ~clk;

    task automatic step(input logic bit_value, input logic reset_value);
        begin
            @(negedge clk);
            in = bit_value;
            reset = reset_value;
            @(posedge clk);
            expected_disc = 0;
            expected_flag = 0;
            expected_err = 0;
            if (reset_value) ones = 0;
            else if (bit_value) begin
                if (ones < 7) ones = ones + 1;
                expected_err = (ones >= 7);
            end else begin
                expected_disc = (ones == 5);
                expected_flag = (ones == 6);
                ones = 0;
            end
            #1;
            if ({disc,flag,err} !== {expected_disc,expected_flag,expected_err})
                $fatal(1, "Mismatch check=%0d input=%b reset=%b got=%b expected=%b",
                       checks, bit_value, reset_value, {disc,flag,err},
                       {expected_disc,expected_flag,expected_err});
            checks = checks + 1;
            // Moore outputs must remain stable when the input changes midcycle.
            in = ~bit_value;
            #1;
            if ({disc,flag,err} !== {expected_disc,expected_flag,expected_err})
                $fatal(1, "Outputs depend directly on input");
        end
    endtask

    initial begin
        step(0, 1);
        for (run_length = 0; run_length <= 12; run_length = run_length + 1) begin
            step(0, 0);
            for (k = 0; k < run_length; k = k + 1) step(1, 0);
            step(0, 0);
            step(1, 0);
            step(0, 0);
        end
        // Exhaust all 12-bit streams with independent reset for each stream.
        for (pattern = 0; pattern < 4096; pattern = pattern + 1) begin
            step(1, 1);
            for (bit_index = 11; bit_index >= 0; bit_index = bit_index - 1)
                step((pattern >> bit_index) & 1, 0);
        end
        // Reset in every run-length state and during each output condition.
        for (run_length = 0; run_length <= 8; run_length = run_length + 1) begin
            step(0, 1);
            for (k = 0; k < run_length; k = k + 1) step(1, 0);
            step(1, 1);
            step(0, 0);
            for (k = 0; k < run_length; k = k + 1) step(1, 0);
            step(0, 0);
            step(0, 1);
        end
        $display("PASS: %0d checked cycles", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Development testbench timeout");
    end
endmodule
