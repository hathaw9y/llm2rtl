`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [9:0] q;
    integer expected = 0;
    integer checked_edges = 0;
    bit initialized = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    // Model the original modulo-1000 sequence using independent integer arithmetic.
    always @(posedge clk) begin
        if (reset) begin
            expected = 0;
            initialized = 1;
        end else if (initialized) begin
            expected = (expected + 1) % 1000;
        end
        #1;
        if (initialized) begin
            if (q !== expected[9:0])
                $fatal(1, "edge %0d expected %0d got %0d", checked_edges, expected, q);
            checked_edges = checked_edges + 1;
        end
    end
    always @(negedge clk) begin
        if (initialized && q !== expected[9:0])
            $fatal(1, "q changed between rising edges");
    end

    task automatic change_reset(input bit value);
        logic [9:0] before_q;
        begin
            before_q = q;
            reset = value;
            #1;
            if (initialized && q !== before_q)
                $fatal(1, "reset changed q away from rising edge");
        end
    endtask

    initial begin
        // No assertion about q before reset: original specification leaves it unspecified.
        #2;
        change_reset(1);
        repeat (3) @(negedge clk);
        change_reset(0);
        repeat (3005) @(negedge clk);
        // Mid-count reset, asserted away from the sampling edge.
        #2;
        change_reset(1);
        repeat (2) @(negedge clk);
        change_reset(0);
        // Synchronous reset pulse entirely between rising edges must have no effect.
        repeat (17) @(negedge clk);
        change_reset(1);
        change_reset(0);
        repeat (982) @(negedge clk);
        if (q !== 10'd999) $fatal(1, "terminal directed case did not reach 999");
        change_reset(1);
        @(negedge clk);
        if (q !== 10'd0) $fatal(1, "reset at terminal value failed");
        change_reset(0);
        repeat (2001) @(negedge clk);
        #2;
        $display("PASS counter sequence, wrap, reset priority and synchronous timing (%0d edges)", checked_edges);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "timeout");
    end
endmodule
