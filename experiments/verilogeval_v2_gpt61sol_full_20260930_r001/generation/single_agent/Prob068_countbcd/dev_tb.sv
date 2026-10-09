`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 1;
    wire [2:0] ena;
    wire [15:0] q;
    integer expected = 0;
    integer checks = 0;
    logic [15:0] expected_q;
    logic [2:0] expected_ena;
    TopModule dut (.clk(clk), .reset(reset), .ena(ena), .q(q));
    always #5 clk = ~clk;

    task automatic check_outputs;
        begin
            expected_q[3:0] = expected % 10;
            expected_q[7:4] = (expected / 10) % 10;
            expected_q[11:8] = (expected / 100) % 10;
            expected_q[15:12] = (expected / 1000) % 10;
            expected_ena[0] = (expected % 10 == 9);
            expected_ena[1] = (expected % 100 == 99);
            expected_ena[2] = (expected % 1000 == 999);
            if (q !== expected_q || ena !== expected_ena)
                $fatal(1, "FAIL count=%0d q=%h expected=%h ena=%b expected=%b", expected, q, expected_q, ena, expected_ena);
            checks = checks + 1;
        end
    endtask

    task automatic step;
        begin
            @(posedge clk);
            if (reset) expected = 0;
            else expected = (expected + 1) % 10000;
            #1;
            check_outputs();
        end
    endtask

    initial begin
        step();
        @(negedge clk); reset = 0;
        repeat (20005) step();
        // Assert reset between edges and verify it is synchronous.
        @(negedge clk); reset = 1;
        #1; check_outputs();
        step();
        step();
        @(negedge clk); reset = 0;
        repeat (1234) step();
        @(negedge clk); reset = 1;
        #1; check_outputs();
        step();
        @(negedge clk); reset = 0;
        repeat (20) step();
        $display("PASS: %0d checks, full decimal rollover and synchronous reset", checks);
        $finish;
    end
    initial begin
        #300000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
