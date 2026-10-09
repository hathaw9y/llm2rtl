`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic in = 1;
    wire done;
    integer checks = 0;
    integer phase = 0;
    logic expected;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .done(done));
    always #5 clk = ~clk;

    task automatic tick(input logic value, input logic rst);
        @(negedge clk);
        in = value;
        reset = rst;
        expected = 0;
        if (rst) phase = 0;
        else if (phase == 0) begin
            if (!value) phase = 1;
        end else if (phase >= 1 && phase <= 8) begin
            phase = phase + 1;
        end else if (phase == 9) begin
            if (value) begin
                expected = 1;
                phase = 0;
            end else phase = 10;
        end else if (value) phase = 0;
        @(posedge clk);
        #1;
        checks = checks + 1;
        if (done !== expected)
            $fatal(1, "FAIL check %0d: done=%b expected=%b", checks, done, expected);
    endtask

    task automatic frame(input logic [7:0] payload, input logic stop_value);
        tick(0, 0);
        for (integer b = 0; b < 8; b = b + 1)
            tick(payload[b], 0);
        tick(stop_value, 0);
    endtask

    initial begin
        tick(1, 1);
        repeat (4) tick(1, 0);
        for (integer p = 0; p < 256; p = p + 1)
            frame(p[7:0], 1);
        frame(8'hA5, 0);
        repeat (20) tick(0, 0);
        tick(1, 0);
        frame(8'h3C, 1);
        // Reset at each position, including the expected stop and recovery.
        for (integer r = 0; r < 12; r = r + 1) begin
            tick(1, 1);
            tick(0, 0);
            repeat (r) tick(0, 0);
            tick(0, 1);
            tick(1, 0);
            frame(8'hFF, 1);
        end
        // Deterministic arbitrary stream with occasional reset.
        for (integer n = 0; n < 4000; n = n + 1)
            tick(($random & 1), (n % 137 == 0));
        tick(1, 1);
        $display("PASS: %0d cycle checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
