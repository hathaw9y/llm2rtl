`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [9:0] data = 0;
    wire tc;
    integer expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .load(load), .data(data), .tc(tc));
    always #5 clk = ~clk;

    task automatic step(input bit do_load, input logic [9:0] value);
        @(negedge clk);
        load = do_load;
        data = value;
        @(posedge clk);
        if (do_load) expected = value;
        else if (expected > 0) expected = expected - 1;
        #1;
        checks = checks + 1;
        if (tc !== (expected == 0))
            $fatal(1, "tc mismatch: expected count=%0d tc=%b", expected, tc);
    endtask

    initial begin
        expected = 0;
        step(1, 0);
        repeat (5) step(0, 0);
        step(1, 1);
        step(0, 0);
        repeat (5) step(0, 0);
        step(1, 10);
        repeat (3) step(0, 0);
        step(1, 2);
        repeat (4) step(0, 0);
        step(1, 1023);
        repeat (1025) step(0, 0);
        for (integer n = 0; n < 1024; n = n + 1) begin
            step(1, n);
            repeat (n + 2) step(0, 0);
        end
        $display("PASS: %0d cycle comparisons", checks);
        $finish;
    end
    initial begin
        #10000000;
        $fatal(1, "testbench timeout");
    end
endmodule
