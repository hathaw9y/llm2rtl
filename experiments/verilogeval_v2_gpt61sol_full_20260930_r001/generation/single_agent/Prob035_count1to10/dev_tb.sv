`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 1;
    wire [3:0] q;
    integer expected = 1;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;
    task automatic check_q(input integer value);
        if (q !== value[3:0])
            $fatal(1, "FAIL expected %0d got %0d", value, q);
        checks = checks + 1;
    endtask
    initial begin
        @(posedge clk); #1; check_q(1);
        @(negedge clk); reset = 0;
        repeat (35) begin
            @(posedge clk);
            expected = (expected == 10) ? 1 : expected + 1;
            #1; check_q(expected);
        end
        // A pulse wholly between rising edges must not reset the counter.
        @(negedge clk); reset = 1;
        #1; check_q(expected);
        reset = 0;
        @(posedge clk);
        expected = (expected == 10) ? 1 : expected + 1;
        #1; check_q(expected);
        // Reset during counting, then hold it across multiple rising edges.
        @(negedge clk); reset = 1;
        #1; check_q(expected);
        repeat (3) begin
            @(posedge clk); #1; check_q(1);
        end
        expected = 1;
        @(negedge clk); reset = 0;
        repeat (20) begin
            @(posedge clk);
            expected = (expected == 10) ? 1 : expected + 1;
            #1; check_q(expected);
        end
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "FAIL timeout");
    end
endmodule
