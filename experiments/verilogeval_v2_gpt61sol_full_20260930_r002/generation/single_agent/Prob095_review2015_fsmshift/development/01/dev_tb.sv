`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire shift_ena;
    integer remaining;
    integer checks = 0;
    bit initialized = 0;
    logic expected;
    TopModule dut (.clk(clk), .reset(reset), .shift_ena(shift_ena));
    always #5 clk = ~clk;

    // Independent oracle: each reset reloads four enabled intervals.
    always @(posedge clk) begin
        if (initialized && shift_ena !== (remaining > 0))
            $fatal(1, "Pre-edge mismatch at %0t", $time);
        if (reset) begin
            remaining = 4;
            initialized = 1;
        end else if (initialized && remaining > 0)
            remaining = remaining - 1;
        #1;
        if (initialized) begin
            expected = (remaining > 0);
            if (shift_ena !== expected)
                $fatal(1, "Post-edge mismatch at %0t: expected %b got %b", $time, expected, shift_ena);
            checks = checks + 1;
        end
    end

    task automatic cycle(input logic reset_value);
        @(negedge clk);
        reset = reset_value;
        @(posedge clk);
        #2;
    endtask

    initial begin
        // No pre-reset value is specified, so do not constrain it.
        cycle(1);
        repeat (12) cycle(0);
        // A pulse with no positive edge must have no effect.
        @(negedge clk);
        reset = 1;
        #1;
        if (shift_ena !== 0) $fatal(1, "Reset acted asynchronously");
        #1 reset = 0;
        repeat (6) cycle(0);
        // Restart at each boundary in the four-cycle sequence.
        for (integer gap = 0; gap <= 4; gap = gap + 1) begin
            cycle(1);
            repeat (gap) cycle(0);
            cycle(1);
            repeat (8) cycle(0);
        end
        // Held reset continually restarts the sequence.
        repeat (5) cycle(1);
        repeat (40) cycle(0);
        if (checks < 100) $fatal(1, "Insufficient checks");
        $display("PASS four-cycle shift enable: %0d checked edges", checks);
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
