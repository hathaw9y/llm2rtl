`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic a = 1'bx;
    wire q;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .a(a), .q(q));
    always #5 clk = ~clk;
    always @(posedge clk) begin
        expected = ~a;
        #1;
        if (q !== expected) $fatal(1, "Mismatch: q=%b expected=%b", q, expected);
        checks = checks + 1;
    end
    initial begin
        // Apply the tabulated input transitions after their coincident edge.
        @(posedge clk); a <= 1'b0;
        #1; if (q !== 1'bx) $fatal(1, "Initial output must be unknown");
        @(posedge clk);
        #1; if (q !== 1'b1) $fatal(1, "Expected inverted zero");
        @(posedge clk);
        @(posedge clk); a <= 1'b1;
        #1; if (q !== 1'b1) $fatal(1, "Coincident transition sampled too early");
        @(posedge clk);
        #1; if (q !== 1'b0) $fatal(1, "Expected inverted one");
        repeat (4) @(posedge clk);
        // Exercise transitions away from clock edges and output stability.
        repeat (16) begin
            @(negedge clk);
            a = ~a;
            #1; if (q !== expected) $fatal(1, "Output changed between rising edges");
            @(posedge clk);
            #2;
        end
        $display("PASS: %0d rising-edge comparisons", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Testbench timeout");
    end
endmodule
