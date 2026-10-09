`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic reset = 1'b0;
    wire [3:0] q;
    integer expected = 0;
    integer checks = 0;
    integer i;
    integer target;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    task automatic check_value(input integer value);
        begin
            if (q !== value[3:0])
                $fatal(1, "q mismatch at %0t: expected %0d, got %b", $time, value, q);
            checks = checks + 1;
        end
    endtask

    // Inputs change away from rising edges; observe after NBA updates.
    task automatic step(input logic reset_value);
        begin
            @(negedge clk);
            check_value(expected);
            reset = reset_value;
            #1;
            check_value(expected); // Synchronous reset cannot change q here.
            @(posedge clk);
            if (reset_value)
                expected = 0;
            else
                expected = (expected + 1) % 10;
            #1;
            check_value(expected);
        end
    endtask

    initial begin
        // No value is required before the first synchronous reset.
        #2 reset = 1'b1;
        @(posedge clk);
        #1;
        check_value(0);
        step(1'b1);
        step(1'b1);
        for (i = 0; i < 35; i = i + 1)
            step(1'b0);
        for (target = 0; target < 10; target = target + 1) begin
            step(1'b1);
            for (i = 0; i < target; i = i + 1)
                step(1'b0);
            step(1'b1);
            step(1'b0);
        end
        // A reset pulse entirely between rising edges must have no effect.
        @(negedge clk);
        check_value(expected);
        reset = 1'b1;
        #1 check_value(expected);
        reset = 1'b0;
        #1 check_value(expected);
        @(posedge clk);
        expected = (expected + 1) % 10;
        #1 check_value(expected);
        for (i = 0; i < 25; i = i + 1)
            step(1'b0);
        $display("PASS decade counter: %0d checks", checks);
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
