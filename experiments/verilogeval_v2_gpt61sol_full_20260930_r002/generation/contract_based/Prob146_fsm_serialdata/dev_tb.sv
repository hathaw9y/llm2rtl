`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic in = 1;
    logic reset = 0;
    wire [7:0] out_byte;
    wire done;
    TopModule dut (.clk(clk), .in(in), .reset(reset), .out_byte(out_byte), .done(done));
    always #5 clk = ~clk;

    // Position-based oracle: -1 scans for start, 0..7 are data,
    // 8 is the expected stop, 9 discards until the line returns high.
    integer position = -1;
    logic [7:0] expected_byte = 0;
    logic expected_done = 0;
    integer samples = 0;
    integer completions = 0;
    integer value;
    integer phase;
    integer j;
    logic [31:0] prng = 32'h134b92a7;

    task automatic sample(input logic serial_bit, input logic rst);
        begin
            @(negedge clk);
            in = serial_bit;
            reset = rst;
            @(posedge clk);
            expected_done = 0;
            if (rst) begin
                position = -1;
                expected_byte = 0;
            end else if (position == -1) begin
                if (!serial_bit) position = 0;
            end else if (position < 8) begin
                expected_byte[position] = serial_bit;
                position = position + 1;
            end else if (position == 8) begin
                if (serial_bit) begin
                    expected_done = 1;
                    position = -1;
                end else position = 9;
            end else if (serial_bit) position = -1;
            #1;
            samples = samples + 1;
            if (done !== expected_done)
                $fatal(1, "done mismatch sample %0d expected %b got %b", samples, expected_done, done);
            if (expected_done) begin
                completions = completions + 1;
                if (out_byte !== expected_byte)
                    $fatal(1, "byte mismatch sample %0d expected %h got %h", samples, expected_byte, out_byte);
            end
        end
    endtask

    task automatic frame(input logic [7:0] data, input logic stop_bit);
        integer k;
        begin
            sample(0, 0);
            for (k = 0; k < 8; k = k + 1) sample(data[k], 0);
            sample(stop_bit, 0);
        end
    endtask

    initial begin
        // No check of unspecified power-up values.
        sample(1, 1);
        repeat (4) sample(1, 0);
        // Exhaustive byte values with no idle gap between frames.
        for (value = 0; value < 256; value = value + 1) frame(value[7:0], 1);
        sample(1, 0);
        frame(8'ha5, 0);
        repeat (24) sample(0, 0);
        sample(1, 0);
        frame(8'h96, 1);
        frame(8'hff, 0);
        sample(1, 0);
        frame(8'h00, 1);
        repeat (5) sample(1, 0);
        // Abort at each position, including the expected stop edge.
        for (phase = 0; phase <= 9; phase = phase + 1) begin
            sample(1, 1);
            sample(1, 0);
            for (j = 0; j < phase; j = j + 1) sample(0, 0);
            sample(0, 1);
            sample(1, 0);
            frame(8'h81, 1);
        end
        frame(8'h35, 0);
        sample(0, 1);
        sample(1, 0);
        frame(8'h42, 1);
        // done remains asserted if reset toggles entirely between rising edges.
        @(negedge clk);
        reset = 1;
        #1;
        if (done !== 1'b1) $fatal(1, "reset acted asynchronously");
        reset = 0;
        sample(1, 0);
        for (j = 0; j < 3000; j = j + 1) begin
            prng = {prng[30:0], prng[31] ^ prng[21] ^ prng[1] ^ prng[0]};
            sample(prng[0], (j % 137 == 0));
        end
        sample(1, 1);
        frame(8'h5a, 1);
        sample(1, 0);
        $display("PASS serial receiver: %0d samples, %0d valid frames", samples, completions);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "timeout");
    end
endmodule
