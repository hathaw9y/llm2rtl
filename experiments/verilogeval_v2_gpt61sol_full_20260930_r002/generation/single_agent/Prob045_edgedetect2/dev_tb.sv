`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic [7:0] in = 8'h00;
    wire [7:0] anyedge;
    logic [7:0] prior_sample = 8'hxx;
    logic [7:0] expected = 8'hxx;
    integer checks = 0;
    integer a, b, bit_index;
    TopModule dut (.clk(clk), .in(in), .anyedge(anyedge));
    always #5 clk = ~clk;

    // Compare sampled values bit by bit; observe after nonblocking updates.
    always @(posedge clk) begin
        for (integer k = 0; k < 8; k = k + 1)
            expected[k] = (in[k] != prior_sample[k]);
        prior_sample = in;
        #1;
        if (anyedge !== expected)
            $fatal(1, "sample %0d: expected %h got %h", checks, expected, anyedge);
        checks = checks + 1;
    end

    task automatic sample(input logic [7:0] value);
        @(negedge clk);
        in = value;
        #1;
        if (anyedge !== expected)
            $fatal(1, "output changed between rising edges");
        @(posedge clk);
        #2;
    endtask

    initial begin
        #2;
        if (anyedge !== 8'hxx)
            $fatal(1, "uninitialized sequential output unexpectedly known");
        sample(8'h00);
        sample(8'hff);
        sample(8'hff);
        sample(8'h00);
        sample(8'haa);
        sample(8'h55);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            sample(8'h00);
            sample(8'h01 << bit_index);
            sample(8'h00);
        end
        // A transient that returns before the sampling edge is not an edge
        // between clock samples. The registered output must remain stable.
        @(negedge clk);
        in = 8'hff;
        #1;
        if (anyedge !== expected) $fatal(1, "glitch changed output");
        in = 8'h00;
        @(posedge clk);
        #2;
        for (a = 0; a < 256; a = a + 1)
            for (b = 0; b < 256; b = b + 1) begin
                sample(a[7:0]);
                sample(b[7:0]);
            end
        sample(8'h00);
        sample(8'h00);
        $display("PASS exhaustive sampled transitions and cycle stability (%0d checks)", checks);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1, "timeout");
    end
endmodule
