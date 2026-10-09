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
    integer checks = 0;
    reg [2:0] expected = 0;
    reg [2:0] previous = 0;
    integer pattern, bit_index, i;
    reg [31:0] random_state = 32'h13579bdf;

    task step(input reg bit_value, input reg reset_value);
        begin
            @(negedge clk);
            previous = expected;
            in = bit_value;
            reset = reset_value;
            #1;
            if ({disc, flag, err} !== previous)
                $fatal(1, "Moore outputs changed between positive edges");
            @(posedge clk);
            expected = 3'b000;
            if (reset_value) begin
                run_length = 0;
            end else if (bit_value) begin
                if (run_length < 7) run_length = run_length + 1;
                if (run_length >= 7) expected[0] = 1;
            end else begin
                if (run_length == 5) expected[2] = 1;
                if (run_length == 6) expected[1] = 1;
                run_length = 0;
            end
            #1;
            checks = checks + 1;
            if ({disc, flag, err} !== expected)
                $fatal(1, "Mismatch check %0d: got %b expected %b", checks,
                       {disc, flag, err}, expected);
            #2;
            if ({disc, flag, err} !== expected)
                $fatal(1, "Output did not hold for cycle");
        end
    endtask

    initial begin
        // Establish a known state through a synchronous reset.
        @(negedge clk);
        reset = 1;
        in = 1;
        @(posedge clk);
        #1;
        if ({disc, flag, err} !== 3'b000) $fatal(1, "Reset outputs");
        // Exhaust every ten-bit stream, including pulse-to-next-run transitions.
        for (pattern = 0; pattern < 1024; pattern = pattern + 1) begin
            step(1, 1);
            for (bit_index = 9; bit_index >= 0; bit_index = bit_index - 1)
                step((pattern >> bit_index) & 1, 0);
            step(0, 0);
        end
        // Long error runs and recovery; reset from all run lengths.
        for (i = 0; i < 40; i = i + 1) step(1, 0);
        step(0, 0);
        for (pattern = 0; pattern < 10; pattern = pattern + 1) begin
            step(0, 1);
            for (i = 0; i < pattern; i = i + 1) step(1, 0);
            step(1, 1);
            step(0, 0);
        end
        // Continuous stream with deterministic pseudo-random reset interruptions.
        for (i = 0; i < 3000; i = i + 1) begin
            random_state = {random_state[30:0],
                random_state[31] ^ random_state[21] ^ random_state[1] ^ random_state[0]};
            step(random_state[0], (random_state[7:0] == 8'hff));
        end
        $display("PASS: %0d HDLC cycle checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
