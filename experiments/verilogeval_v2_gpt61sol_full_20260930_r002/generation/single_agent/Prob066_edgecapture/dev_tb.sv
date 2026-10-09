`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [31:0] in = 0;
    wire [31:0] out;
    logic [31:0] expected = 'x;
    logic [31:0] previous_sample = 'x;
    logic [31:0] held;
    integer checks = 0;
    integer bit_index;
    integer n;
    logic [31:0] pattern;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));
    always #5 clk = ~clk;

    // Per-bit oracle compares adjacent sampled cycles, with reset priority.
    always @(posedge clk) begin
        for (integer b = 0; b < 32; b = b + 1) begin
            if (reset)
                expected[b] = 1'b0;
            else if (previous_sample[b] === 1'b1 && in[b] === 1'b0)
                expected[b] = 1'b1;
        end
        previous_sample = in;
        #1;
        if (out !== expected)
            $fatal(1, "Mismatch check %0d: expected %h actual %h", checks, expected, out);
        checks = checks + 1;
    end

    task automatic step(input logic rst, input logic [31:0] value);
        @(negedge clk);
        held = out;
        reset = rst;
        in = value;
        #1;
        if (out !== held)
            $fatal(1, "Output changed between rising edges");
        @(posedge clk);
        #2;
    endtask

    initial begin
        // Initial state is unspecified; a reset establishes known output.
        step(1, 32'hffffffff);
        step(0, 32'h00000000); // Falling edges immediately after reset.
        step(0, 32'hffffffff);
        step(0, 32'hffffffff); // Captures persist on stable and rising inputs.
        step(1, 32'h00000000); // Reset wins over all falling edges.
        step(0, 32'h00000000);
        for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1) begin
            pattern = 32'h1 << bit_index;
            step(1, 32'h00000000);
            step(0, pattern);
            step(0, 32'h00000000);
            step(0, pattern);
            step(0, 32'h00000000);
        end
        step(1, 32'haaaaaaaa);
        step(0, 32'h55555555);
        step(0, 32'haaaaaaaa);
        step(1, 32'hffffffff);
        step(1, 32'h00000000);
        step(0, 32'h00000000);
        for (n = 0; n < 200; n = n + 1)
            step((n % 19) == 0, $urandom);
        $display("PASS: %0d sampled-cycle checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
