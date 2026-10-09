`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 1;
    wire [4:0] q;
    logic [4:0] expected;
    logic [31:0] seen;
    logic [4:0] held;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    task automatic tick;
        @(posedge clk);
        #1;
    endtask

    initial begin
        #2000;
        $fatal(1, "FAIL: simulation timeout");
    end

    initial begin
        tick();
        if (q !== 5'd1) $fatal(1, "FAIL: reset value");
        @(negedge clk);
        reset = 0;
        expected = 5'd1;
        seen = 32'd0;
        for (i = 0; i < 31; i = i + 1) begin
            if (q == 0 || seen[q]) $fatal(1, "FAIL: zero or premature repeat at step %0d", i);
            seen[q] = 1'b1;
            // Independently compute right shift and conditional tap mask.
            expected = (expected >> 1) ^ (expected[0] ? 5'b10100 : 5'b00000);
            tick();
            if (q !== expected) $fatal(1, "FAIL: state at step %0d, got %b expected %b", i, q, expected);
        end
        if (q !== 5'd1 || seen !== 32'hfffffffe)
            $fatal(1, "FAIL: period or state coverage");
        tick();
        @(negedge clk);
        held = q;
        #1 reset = 1;
        #1;
        if (q !== held) $fatal(1, "FAIL: reset acted asynchronously");
        tick();
        if (q !== 5'd1) $fatal(1, "FAIL: reset during activity");
        tick();
        if (q !== 5'd1) $fatal(1, "FAIL: held reset");
        @(negedge clk);
        reset = 0;
        tick();
        if (q !== 5'b10100) $fatal(1, "FAIL: restart sequence");
        $display("PASS: recurrence, 31-state period, synchronous reset, held reset, restart");
        $finish;
    end
endmodule
