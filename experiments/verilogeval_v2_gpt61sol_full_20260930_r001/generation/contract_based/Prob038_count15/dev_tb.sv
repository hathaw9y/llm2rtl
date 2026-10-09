`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 1;
    wire [3:0] q;
    integer expected = 0;
    integer checks = 0;
    logic known = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    task automatic check_q;
        begin
            if (q !== expected[3:0])
                $fatal(1, "q=%b expected=%0d at %0t", q, expected, $time);
            checks = checks + 1;
        end
    endtask

    always @(posedge clk) begin
        if (reset) begin
            expected = 0;
            known = 1;
        end else if (known)
            expected = (expected + 1) % 16;
        #1;
        if (known) check_q();
    end
    always @(negedge clk) begin
        #1;
        if (known) check_q();
    end

    initial begin
        // Establish state, hold reset, then cover several complete periods.
        repeat (3) @(negedge clk);
        #2 reset = 0;
        repeat (50) @(negedge clk);
        // Assert between edges: reset must have no immediate effect.
        #2 reset = 1;
        #1 check_q();
        repeat (3) @(negedge clk);
        #2 reset = 0;
        #1 check_q();
        repeat (20) @(negedge clk);
        // A reset pulse entirely between rising edges must not reset q.
        #1 reset = 1;
        #1 check_q();
        #1 reset = 0;
        #1 check_q();
        repeat (20) @(negedge clk);
        #2;
        $display("PASS: %0d checks; count periods, wraparound, synchronous reset and hold behavior", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "development test timeout");
    end
endmodule
