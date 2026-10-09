`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg in = 1;
    wire done;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .done(done));
    always #5 clk = ~clk;

    // Independent protocol oracle: countdown includes data and stop samples.
    integer remaining = 0;
    reg recovering = 0;
    reg expected_done = 0;
    reg initialized = 0;
    integer samples = 0;
    integer i, j;
    reg [7:0] payload;

    task tick(input reg value, input reg rst);
        begin
            @(negedge clk);
            in = value;
            reset = rst;
            #1;
            if (initialized && done !== expected_done)
                $fatal(1, "Output changed between rising edges at sample %0d", samples);
            @(posedge clk);
            expected_done = 0;
            if (rst) begin
                remaining = 0;
                recovering = 0;
                initialized = 1;
            end else if (recovering) begin
                if (value) recovering = 0;
            end else if (remaining > 1) begin
                remaining = remaining - 1;
            end else if (remaining == 1) begin
                remaining = 0;
                if (value) expected_done = 1;
                else recovering = 1;
            end else if (!value) begin
                remaining = 9;
            end
            #1;
            samples = samples + 1;
            if (done !== expected_done)
                $fatal(1, "sample %0d: in=%b reset=%b expected done=%b got=%b", samples, value, rst, expected_done, done);
        end
    endtask

    task frame(input reg [7:0] data, input reg stop_value);
        integer bit_number;
        begin
            tick(0, 0);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1)
                tick(data[bit_number], 0);
            tick(stop_value, 0);
        end
    endtask

    initial begin
        tick(1, 1);
        repeat (4) tick(1, 0);
        frame(8'h00, 1);
        frame(8'hff, 1); // Start immediately after the preceding stop.
        frame(8'ha5, 1);
        tick(1, 0);
        frame(8'h5a, 0);
        repeat (20) tick(0, 0);
        tick(1, 0); // Recovery stop is not a completed byte.
        frame(8'h81, 1);
        // Exhaustive byte values with no idle gap.
        for (i = 0; i < 256; i = i + 1)
            frame(i[7:0], 1);
        // Reset at each position of a frame, including the expected stop.
        for (i = 0; i <= 9; i = i + 1) begin
            tick(1, 1);
            tick(0, 0);
            for (j = 0; j < i; j = j + 1) tick(0, 0);
            tick(0, 1);
            frame(8'hc3, 1);
        end
        frame(8'h12, 0);
        tick(0, 1); // Reset while waiting for recovery.
        frame(8'h34, 1);
        tick(1, 1); // Reset suppresses an existing done pulse.
        for (i = 0; i < 3000; i = i + 1)
            tick($random, (($random & 63) == 0));
        tick(1, 1);
        frame(8'h96, 1);
        tick(1, 0);
        $display("PASS: serial framing, recovery, synchronous reset, and random stream (%0d samples)", samples);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
