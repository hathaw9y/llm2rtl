`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic in = 0;
    wire disc, flag, err;
    integer run_length = 0;
    integer cycles = 0;
    logic [2:0] expected = 0;
    integer length, j, pattern;

    TopModule dut (.clk(clk), .reset(reset), .in(in),
                   .disc(disc), .flag(flag), .err(err));
    always #5 clk = ~clk;

    task automatic check_outputs;
        begin
            if ({disc, flag, err} !== expected)
                $fatal(1, "cycle %0d run %0d expected %b got %b", cycles,
                       run_length, expected, {disc, flag, err});
        end
    endtask

    // Oracle counts sampled ones, independently of the DUT state encoding.
    task automatic step(input logic bit_value, input logic reset_value);
        begin
            @(negedge clk);
            in = bit_value;
            reset = reset_value;
            #1;
            if (cycles > 0) check_outputs();
            @(posedge clk);
            expected = 3'b000;
            if (reset_value) run_length = 0;
            else if (bit_value) begin
                run_length = run_length + 1;
                if (run_length >= 7) expected[0] = 1'b1;
            end else begin
                if (run_length == 5) expected[2] = 1'b1;
                if (run_length == 6) expected[1] = 1'b1;
                run_length = 0;
            end
            cycles = cycles + 1;
            #1;
            check_outputs();
            #2;
            check_outputs();
        end
    endtask

    initial begin
        step(1, 1);
        step(1, 1);
        step(0, 0);
        // All boundaries, prolonged error, and recognition after a terminating zero.
        for (length = 0; length <= 20; length = length + 1) begin
            step(0, 0);
            for (j = 0; j < length; j = j + 1) step(1, 0);
            step(0, 0);
            for (j = 0; j < 5; j = j + 1) step(1, 0);
            step(0, 0);
        end
        // Synchronous reset interrupts every relevant run length.
        for (length = 0; length <= 9; length = length + 1) begin
            step(0, 1);
            for (j = 0; j < length; j = j + 1) step(1, 0);
            step(1, 1);
            step(0, 0);
        end
        // Exhaustive streams include adjacent and overlapping recognition patterns.
        for (pattern = 0; pattern < 1024; pattern = pattern + 1) begin
            step(0, 1);
            for (j = 9; j >= 0; j = j - 1) step((pattern >> j) & 1, 0);
            step(0, 0);
        end
        $display("PASS: HDLC sequence, reset, and Moore cycle checks (%0d cycles)", cycles);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
