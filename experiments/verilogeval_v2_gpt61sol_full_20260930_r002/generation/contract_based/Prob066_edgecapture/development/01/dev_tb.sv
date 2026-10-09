`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [31:0] in = 0;
    wire [31:0] out;
    logic previous_sample [0:31];
    logic captured [0:31];
    logic [31:0] expected;
    logic initialized = 0;
    integer checks = 0;
    logic [31:0] rng = 32'h96abc123;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));
    always #5 clk = ~clk;

    // Independent scalar oracle: update each lane from sampled input history.
    always @(posedge clk) begin
        for (integer b = 0; b < 32; b = b + 1) begin
            if (reset)
                captured[b] = 0;
            else if (previous_sample[b] === 1'b1 && in[b] === 1'b0)
                captured[b] = 1;
            previous_sample[b] = in[b];
            expected[b] = captured[b];
        end
        if (reset) initialized = 1;
        #1;
        if (initialized) begin
            if (out !== expected)
                $fatal(1, "Mismatch check=%0d reset=%b in=%h expected=%h got=%h", checks, reset, in, expected, out);
            checks = checks + 1;
        end
    end

    task automatic cycle(input logic rst, input logic [31:0] value);
        @(negedge clk);
        reset = rst;
        in = value;
        @(posedge clk);
        #2;
    endtask

    initial begin
        // No asserted requirement on unspecified power-up state.
        cycle(1, 32'b0);
        cycle(0, 32'b0);
        cycle(0, 32'hffffffff);
        cycle(0, 32'hffffffff);
        cycle(0, 32'b0);
        cycle(0, 32'hffffffff);
        cycle(0, 32'b0);
        // An asserted reset between rising edges must not clear immediately.
        @(negedge clk);
        reset = 1;
        #1;
        if (out !== 32'hffffffff) $fatal(1, "Reset acted asynchronously");
        @(posedge clk);
        #2;
        if (out !== 32'b0) $fatal(1, "Reset failed at rising edge");
        cycle(1, 32'hffffffff);
        cycle(0, 32'b0);
        cycle(1, 32'hffffffff);
        cycle(1, 32'b0); // Reset must dominate simultaneous falling transitions.
        cycle(0, 32'b0);
        for (integer lane = 0; lane < 32; lane = lane + 1) begin
            cycle(1, 32'b0);
            cycle(0, 32'b1 << lane);
            cycle(0, 32'b0);
            if (out !== (32'b1 << lane)) $fatal(1, "Lane independence failed %0d", lane);
            cycle(0, 32'hffffffff);
            cycle(0, 32'hffffffff);
        end
        cycle(1, 32'b0);
        cycle(0, 32'hffffffff);
        cycle(0, 32'haaaaaaaa);
        cycle(0, 32'h55555555);
        cycle(0, 32'b0);
        cycle(1, 32'b0);
        cycle(0, 32'b0);
        // A high/low pulse entirely between sampled edges creates no event.
        @(negedge clk);
        in = 32'hffffffff;
        #1 in = 32'b0;
        @(posedge clk);
        #2;
        if (out !== 32'b0) $fatal(1, "Unsampled pulse captured");
        for (integer n = 0; n < 300; n = n + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            cycle((n % 19) == 0, rng);
        end
        $display("PASS %0d sampled checks plus directed assertions", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
