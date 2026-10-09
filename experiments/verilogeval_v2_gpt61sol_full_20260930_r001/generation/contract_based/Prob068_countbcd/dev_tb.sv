`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 1;
    wire [2:0] ena;
    wire [15:0] q;
    integer expected = 0;
    integer checks = 0;
    TopModule dut(.clk(clk), .reset(reset), .ena(ena), .q(q));
    always #5 clk = ~clk;

    task automatic check_outputs;
        logic [15:0] packed_expected;
        logic [2:0] enable_expected;
        begin
            packed_expected[3:0] = expected % 10;
            packed_expected[7:4] = (expected / 10) % 10;
            packed_expected[11:8] = (expected / 100) % 10;
            packed_expected[15:12] = (expected / 1000) % 10;
            enable_expected[0] = (expected % 10 == 9);
            enable_expected[1] = (expected % 100 == 99);
            enable_expected[2] = (expected % 1000 == 999);
            if (q !== packed_expected || ena !== enable_expected)
                $fatal(1, "Mismatch expected count=%0d q=%h ena=%b actual q=%h ena=%b", expected, packed_expected, enable_expected, q, ena);
            checks = checks + 1;
        end
    endtask

    task automatic tick(input logic reset_value);
        begin
            @(negedge clk);
            reset = reset_value;
            #1;
            check_outputs(); // Reset must not change the state between edges.
            @(posedge clk);
            if (reset_value) expected = 0;
            else expected = (expected + 1) % 10000;
            #1;
            check_outputs();
        end
    endtask

    initial begin
        @(posedge clk);
        #1;
        check_outputs();
        tick(1);
        tick(1);
        repeat (20019) tick(0);
        // Current count is 19: reset with the tens carry pending.
        tick(1);
        repeat (999) tick(0);
        // Reset with all three carry outputs high at 0999.
        tick(1);
        tick(1);
        repeat (37) tick(0);
        tick(1);
        tick(0);
        $display("PASS: %0d output checks; two full decimal periods and synchronous resets", checks);
        $finish;
    end
    initial begin
        #300000;
        $fatal(1, "Testbench timeout");
    end
endmodule
