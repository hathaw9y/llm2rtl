`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [9:0] q;
    integer expected = 0;
    integer checks = 0;
    integer wraps = 0;
    logic initialized = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            expected = 0;
            initialized = 1;
        end else if (initialized) begin
            expected = (expected + 1) % 1000;
            if (expected == 0) wraps = wraps + 1;
        end
        #1;
        if (initialized) begin
            if (q !== expected[9:0])
                $fatal(1, "Mismatch: q=%0d expected=%0d", q, expected);
            checks = checks + 1;
        end
    end

    task automatic reset_between_edges;
        logic [9:0] held;
        begin
            @(negedge clk);
            held = q;
            #1 reset = 1;
            #1;
            if (q !== held) $fatal(1, "Reset changed output asynchronously");
            reset = 0;
            #1;
            if (q !== held) $fatal(1, "Reset deassertion changed output");
        end
    endtask

    initial begin
        // Initialize solely with the specified synchronous reset.
        @(negedge clk) reset = 1;
        repeat (3) @(negedge clk);
        reset = 0;
        repeat (3100) @(negedge clk);
        reset_between_edges();
        @(negedge clk) reset = 1;
        repeat (2) @(negedge clk);
        reset = 0;
        // Assert reset when the pre-edge count is exactly 999.
        repeat (999) @(negedge clk);
        if (q !== 10'd999) $fatal(1, "Terminal count was not reached");
        reset = 1;
        @(negedge clk);
        if (q !== 10'd0) $fatal(1, "Terminal reset failed");
        reset = 0;
        repeat (1100) @(negedge clk);
        if (wraps < 4) $fatal(1, "Insufficient wrap coverage");
        $display("PASS: %0d edge comparisons, %0d natural wraps, synchronous and terminal reset", checks, wraps);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Development simulation timeout");
    end
endmodule
