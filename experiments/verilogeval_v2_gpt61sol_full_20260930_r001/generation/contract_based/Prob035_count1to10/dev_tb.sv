`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 1;
    wire [3:0] q;
    integer expected = 0;
    integer checks = 0;
    logic initialized = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    task automatic check_value(input integer value);
        if (q !== value[3:0])
            $fatal(1, "FAIL: t=%0t expected=%0d got=%0d", $time, value, q);
        checks = checks + 1;
    endtask

    always @(posedge clk) begin
        if (reset) begin
            expected = 1;
            initialized = 1;
        end else if (initialized) begin
            expected = (expected % 10) + 1;
        end
        #1;
        if (initialized) check_value(expected);
    end

    always @(negedge clk) begin
        if (initialized) check_value(expected);
    end

    initial begin
        // Establish state, then verify reset remains asserted for several cycles.
        repeat (3) @(negedge clk);
        #1 reset = 0;
        repeat (35) @(negedge clk);
        // Assert between edges and prove reset does not act asynchronously.
        #1 reset = 1;
        #1 check_value(expected);
        @(negedge clk);
        #1 reset = 0;
        // A pulse that misses every rising edge must not reset the counter.
        @(negedge clk);
        #1 reset = 1;
        #1 check_value(expected);
        #1 reset = 0;
        #1 check_value(expected);
        // Reach 10 and check reset priority on the next edge.
        wait (q === 4'd10);
        @(negedge clk);
        #1 reset = 1;
        #1 check_value(10);
        repeat (2) @(negedge clk);
        #1 reset = 0;
        repeat (25) @(negedge clk);
        #2;
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
