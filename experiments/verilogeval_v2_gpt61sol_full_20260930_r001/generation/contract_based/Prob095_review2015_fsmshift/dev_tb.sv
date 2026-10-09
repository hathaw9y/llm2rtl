`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire shift_ena;
    integer remaining = 0;
    integer checks = 0;
    integer phase;
    integer i;
    logic [15:0] random_r = 16'hcafe;
    TopModule dut (.clk(clk), .reset(reset), .shift_ena(shift_ena));
    always #5 clk = ~clk;

    task automatic step(input logic rst);
        @(negedge clk);
        reset = rst;
        @(posedge clk);
        if (rst) remaining = 4;
        else if (remaining > 0) remaining = remaining - 1;
        #1;
        checks = checks + 1;
        if (shift_ena !== (remaining > 0))
            $fatal(1, "FAIL check=%0d reset=%b remaining=%0d actual=%b", checks, rst, remaining, shift_ena);
    endtask

    initial begin
        step(1);
        repeat (12) step(0);
        for (phase = 0; phase < 5; phase = phase + 1) begin
            step(1);
            repeat (phase) step(0);
            step(1);
            repeat (8) step(0);
        end
        repeat (5) step(1);
        repeat (10) step(0);
        // A pulse with no rising edge must not restart the exhausted sequence.
        @(negedge clk);
        #1 reset = 1;
        #1;
        if (shift_ena !== 1'b0) $fatal(1, "FAIL asynchronous assertion");
        reset = 0;
        @(posedge clk);
        #1;
        if (shift_ena !== 1'b0) $fatal(1, "FAIL between-edge pulse restarted sequence");
        for (i = 0; i < 300; i = i + 1) begin
            random_r = {random_r[14:0],random_r[15]^random_r[13]^random_r[12]^random_r[10]};
            step(random_r[3:0] == 4'h0);
        end
        step(1);
        repeat (100) step(0);
        $display("PASS: %0d cycle comparisons plus synchronous reset pulse checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL watchdog timeout");
    end
endmodule
