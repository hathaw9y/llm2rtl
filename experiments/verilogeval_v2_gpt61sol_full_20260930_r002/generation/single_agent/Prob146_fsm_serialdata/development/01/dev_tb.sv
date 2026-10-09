`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic in = 1;
    logic reset = 0;
    wire [7:0] out_byte;
    wire done;
    TopModule dut (.clk(clk), .in(in), .reset(reset), .out_byte(out_byte), .done(done));
    always #5 clk = ~clk;

    // Independent protocol oracle: -1 seeks start, 0..7 collect,
    // 8 verifies stop, and 9 discards input until idle is seen.
    integer position = -1;
    integer cycles = 0;
    integer successes = 0;
    logic [7:0] expected_byte = 0;
    logic expected_done;
    logic initialized = 0;
    always @(posedge clk) begin
        expected_done = 0;
        if (reset) begin
            position = -1;
            expected_byte = 0;
            initialized = 1;
        end else if (initialized) begin
            if (position == -1) begin
                if (in == 0) position = 0;
            end else if (position < 8) begin
                expected_byte[position] = in;
                position = position + 1;
            end else if (position == 8) begin
                if (in == 1) begin
                    expected_done = 1;
                    position = -1;
                end else position = 9;
            end else if (in == 1) position = -1;
        end
        #1;
        if (initialized) begin
            cycles = cycles + 1;
            if (done !== expected_done)
                $fatal(1, "done mismatch cycle %0d expected %b got %b", cycles, expected_done, done);
            if (expected_done) begin
                successes = successes + 1;
                if (out_byte !== expected_byte)
                    $fatal(1, "byte mismatch cycle %0d expected %h got %h", cycles, expected_byte, out_byte);
            end
        end
    end

    task automatic sample(input logic serial_bit, input logic rst);
        @(negedge clk);
        in = serial_bit;
        reset = rst;
        @(posedge clk);
        #2;
    endtask
    task automatic frame(input logic [7:0] payload, input logic stop_bit);
        sample(0, 0);
        for (integer b = 0; b < 8; b = b + 1)
            sample(payload[b], 0);
        sample(stop_bit, 0);
    endtask

    initial begin
        // Establish state only through synchronous reset; pre-reset is unspecified.
        sample(1, 1);
        repeat (5) sample(1, 0);
        // Exhaust all byte values, with no idle cycles between valid frames.
        for (integer v = 0; v < 256; v = v + 1)
            frame(v[7:0], 1);
        frame(8'h96, 0);
        repeat (19) sample(0, 0);
        sample(1, 0); // Recovery delimiter must not report the discarded byte.
        frame(8'h69, 1);
        frame(8'h00, 0);
        sample(1, 0);
        frame(8'hff, 1);
        // Reset during every possible frame phase, including stop and recovery.
        for (integer phase = 0; phase <= 9; phase = phase + 1) begin
            sample(0, 0);
            for (integer b = 0; b < phase; b = b + 1)
                sample(0, 0);
            sample(0, 1);
            frame(8'ha5, 1);
        end
        // Unstructured bit streams stress false starts and stop recovery.
        for (integer k = 0; k < 2000; k = k + 1)
            sample($urandom_range(0, 1), (k % 173 == 0));
        sample(1, 1);
        frame(8'h81, 1);
        repeat (4) sample(1, 0);
        if (successes < 269) $fatal(1, "missing directed completions");
        $display("PASS serial receiver: %0d cycles, %0d valid frames", cycles, successes);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "timeout");
    end
endmodule
