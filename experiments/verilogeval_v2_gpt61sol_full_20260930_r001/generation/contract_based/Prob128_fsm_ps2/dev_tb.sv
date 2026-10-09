`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [7:0] in = 0;
    wire done;
    integer remaining = 0;
    integer checks = 0;
    logic expected_done = 0;
    logic [31:0] rng = 32'h8c172359;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .done(done));
    always #5 clk = ~clk;

    task automatic step(input logic rst, input logic [7:0] value);
        @(negedge clk);
        reset = rst;
        in = value;
        // A synchronous reset must not alter completion before the clock edge.
        #1;
        if (checks > 0 && done !== expected_done)
            $fatal(1, "Output changed between rising edges at check %0d", checks);
        @(posedge clk);
        expected_done = 0;
        if (rst) remaining = 0;
        else if (remaining > 0) begin
            remaining = remaining - 1;
            expected_done = (remaining == 0);
        end else if (value[3]) remaining = 2;
        #1;
        checks = checks + 1;
        if (done !== expected_done)
            $fatal(1, "Mismatch check=%0d byte=%h reset=%b expected=%b actual=%b", checks, value, rst, expected_done, done);
    endtask

    initial begin
        step(1, 8'hff);
        for (integer n = 0; n < 256; n = n + 1)
            if ((n & 8) == 0) step(0, n[7:0]);
        // Every combination of the two payload marker bits, repeated messages.
        for (integer p = 0; p < 4; p = p + 1) begin
            step(0, 8'h08);
            step(0, (p & 1) ? 8'hff : 8'h00);
            step(0, (p & 2) ? 8'h08 : 8'hf7);
        end
        step(0, 8'h00);
        // Reset interrupts each phase and wins over an input marker.
        for (integer phase = 0; phase < 4; phase = phase + 1) begin
            step(1, 8'h08);
            for (integer b = 0; b < phase; b = b + 1)
                step(0, 8'h08);
            step(1, 8'hff);
            step(0, 8'h00);
            step(0, 8'h08);
            step(0, 8'h00);
            step(0, 8'h00);
        end
        for (integer k = 0; k < 5000; k = k + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            step(rng[15:8] == 8'h00, rng[7:0]);
        end
        $display("PASS: %0d cycle checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Testbench timeout");
    end
endmodule
