`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [4:0] q;
    logic [4:0] expected;
    logic [4:0] held;
    logic [31:0] seen;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    task automatic compare(input logic [4:0] want);
        if (q !== want)
            $fatal(1, "state mismatch: expected=%b actual=%b", want, q);
        checks = checks + 1;
    endtask

    task automatic advance;
        expected = (expected >> 1) ^ (expected[0] ? 5'b10100 : 5'b00000);
        @(posedge clk); #1;
        compare(expected);
        held = q;
        @(negedge clk); #1;
        compare(held);
    endtask

    initial begin
        #1; reset = 1;
        @(posedge clk); #1; expected = 5'd1; compare(expected);
        @(negedge clk); #1; reset = 0;
        for (integer period = 0; period < 2; period = period + 1) begin
            seen = 32'b0;
            for (integer step = 0; step < 31; step = step + 1) begin
                if (q === 5'b00000 || (^q) === 1'bx)
                    $fatal(1, "zero or unknown state");
                if (seen[q]) $fatal(1, "early repeated state");
                seen[q] = 1'b1;
                advance();
            end
            compare(5'd1);
            if (seen !== 32'hfffffffe) $fatal(1, "nonzero state coverage incomplete");
        end
        repeat (7) advance();
        held = q;
        reset = 1; #1; compare(held);
        @(posedge clk); #1; expected = 5'd1; compare(expected);
        repeat (2) begin
            @(negedge clk); #1; compare(5'd1);
            @(posedge clk); #1; compare(5'd1);
        end
        reset = 0; #1; compare(5'd1);
        @(negedge clk); #1;
        repeat (31) advance();
        compare(5'd1);
        $display("PASS: sequence, 31-state period, synchronous reset and stability; %0d comparisons", checks);
        $finish;
    end
    initial begin
        #5000; $fatal(1, "development timeout");
    end
endmodule
