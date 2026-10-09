`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic resetn = 1'b1;
    logic in = 1'b0;
    wire out;
    logic stage1, stage2, stage3, stage4;
    logic previous_out;
    integer checks = 0;
    integer i;
    logic [15:0] pattern = 16'b1011000101110010;

    TopModule dut (.clk(clk), .resetn(resetn), .in(in), .out(out));
    always #5 clk = ~clk;

    // Independent model: four serial D flops, reset only at rising edges.
    always @(posedge clk) begin
        if (!resetn) begin
            stage1 <= 1'b0;
            stage2 <= 1'b0;
            stage3 <= 1'b0;
            stage4 <= 1'b0;
        end else begin
            stage1 <= in;
            stage2 <= stage1;
            stage3 <= stage2;
            stage4 <= stage3;
        end
        #1;
        if (out !== stage4)
            $fatal(1, "Rising-edge mismatch at %0t: expected %b got %b", $time, stage4, out);
        checks = checks + 1;
    end

    task automatic cycle(input logic rst, input logic data);
        @(negedge clk);
        previous_out = out;
        resetn = rst;
        in = data;
        #2;
        if (out !== previous_out)
            $fatal(1, "Output changed without a rising clock edge at %0t", $time);
        @(posedge clk);
        #2;
    endtask

    initial begin
        // First sampled edge explicitly resets the otherwise uninitialized flops.
        resetn = 1'b0;
        @(posedge clk);
        #2;
        cycle(1'b0, 1'b1);
        // Single-bit impulse exercises the exact four-flop delay.
        cycle(1'b1, 1'b1);
        repeat (6) cycle(1'b1, 1'b0);
        repeat (6) cycle(1'b1, 1'b1);
        // A reset pulse wholly between rising edges must have no effect.
        @(negedge clk);
        resetn = 1'b0;
        #1;
        if (out !== 1'b1) $fatal(1, "Reset acted asynchronously");
        resetn = 1'b1;
        #1;
        if (out !== 1'b1) $fatal(1, "Between-edge reset pulse changed output");
        @(posedge clk);
        #2;
        cycle(1'b0, 1'b1);
        repeat (5) cycle(1'b1, 1'b0);
        for (i = 0; i < 16; i = i + 1)
            cycle(1'b1, pattern[i]);
        cycle(1'b0, 1'b0);
        cycle(1'b0, 1'b1);
        repeat (8) cycle(1'b1, 1'b1);
        repeat (8) cycle(1'b1, 1'b0);
        $display("PASS: four-flop shift register, %0d rising-edge checks", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
