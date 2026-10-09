`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire shift_ena;
    integer remaining = 0;
    integer checks = 0;
    bit initialized = 0;
    logic held;
    TopModule dut (.clk(clk), .reset(reset), .shift_ena(shift_ena));
    always #5 clk = ~clk;

    // Independent oracle: number of enabled clock intervals left.
    always @(posedge clk) begin
        if (reset) begin
            remaining = 4;
            initialized = 1;
        end else if (initialized && remaining > 0)
            remaining = remaining - 1;
        #1;
        if (initialized) begin
            if (shift_ena !== (remaining > 0))
                $fatal(1, "edge mismatch t=%0t reset=%b remaining=%0d got=%b", $time, reset, remaining, shift_ena);
            checks = checks + 1;
        end
    end

    task automatic step(input logic reset_value);
        @(negedge clk);
        held = shift_ena;
        reset = reset_value;
        #1;
        if (initialized && shift_ena !== held)
            $fatal(1, "reset affected output without rising edge");
        @(posedge clk);
        #2;
    endtask

    initial begin
        // No output expectation before first synchronous reset.
        step(1);
        step(0);
        step(0);
        step(0);
        step(0);
        repeat (24) step(0);
        // Sustained reset holds the first enabled state.
        repeat (5) step(1);
        repeat (6) step(0);
        // Restart during every active phase, including the boundary.
        for (integer phase = 0; phase <= 4; phase = phase + 1) begin
            step(1);
            repeat (phase) step(0);
            step(1);
            repeat (6) step(0);
        end
        // Pulse entirely between rising edges must not restart.
        @(negedge clk);
        held = shift_ena;
        #1 reset = 1;
        #1;
        if (shift_ena !== held) $fatal(1, "asynchronous assertion detected");
        reset = 0;
        #1;
        if (shift_ena !== held) $fatal(1, "asynchronous deassertion detected");
        repeat (32) step(0);
        // Repeat the off-edge pulse while active.
        step(1);
        @(negedge clk);
        reset = 0;
        #1 reset = 1;
        #1 reset = 0;
        repeat (6) step(0);
        if (checks < 100) $fatal(1, "insufficient checks");
        $display("PASS: synchronous reset and four enabled cycles verified (%0d edge checks)", checks);
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "timeout");
    end
endmodule
