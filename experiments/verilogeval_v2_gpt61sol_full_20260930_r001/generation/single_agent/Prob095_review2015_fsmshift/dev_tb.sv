`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire shift_ena;
    integer expected_count = 4;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .shift_ena(shift_ena));
    always #5 clk = ~clk;

    task automatic step(input logic rst);
        @(negedge clk);
        reset = rst;
        @(posedge clk);
        if (rst) expected_count = 0;
        else if (expected_count < 4) expected_count = expected_count + 1;
        #1;
        if (shift_ena !== (expected_count < 4))
            $fatal(1, "Mismatch count=%0d reset=%b output=%b", expected_count, rst, shift_ena);
        checks = checks + 1;
    endtask

    initial begin
        step(1);
        repeat (12) step(0);
        // A reset pulse between rising edges must not restart the counter.
        @(negedge clk);
        reset = 1;
        #2;
        if (shift_ena !== 0) $fatal(1, "Reset acted asynchronously");
        reset = 0;
        step(0);
        // Restart while active and hold reset for multiple cycles.
        step(1);
        step(0);
        step(0);
        step(1);
        repeat (8) step(0);
        repeat (3) step(1);
        repeat (100) step(0);
        $display("PASS: %0d cycle checks, synchronous reset pulse, restart and saturation", checks);
        $finish;
    end
    initial begin
        #5000;
        $fatal(1, "Testbench timeout");
    end
endmodule
