`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [2:0] ena;
    wire [15:0] q;
    integer expected = 0;
    integer i;
    TopModule dut(.clk(clk), .reset(reset), .ena(ena), .q(q));

    task check;
        reg [15:0] expected_bcd;
        reg [2:0] expected_ena;
        begin
            expected_bcd[3:0] = expected % 10;
            expected_bcd[7:4] = (expected / 10) % 10;
            expected_bcd[11:8] = (expected / 100) % 10;
            expected_bcd[15:12] = (expected / 1000) % 10;
            expected_ena[0] = (expected % 10 == 9);
            expected_ena[1] = (expected % 100 == 99);
            expected_ena[2] = (expected % 1000 == 999);
            if (q !== expected_bcd)
                $fatal(1, "Count mismatch: decimal=%0d expected=%h actual=%h", expected, expected_bcd, q);
            if (ena !== expected_ena)
                $fatal(1, "Enable mismatch: decimal=%0d expected=%b actual=%b", expected, expected_ena, ena);
        end
    endtask

    task tick;
        input reset_value;
        begin
            clk = 0;
            reset = reset_value;
            #2;
            check(); // reset assertion must not change state before the edge
            clk = 1;
            if (reset_value) expected = 0;
            else expected = (expected + 1) % 10000;
            #1;
            check();
            clk = 0;
            #1;
            check();
        end
    endtask

    initial begin
        // The specification gives no initial state; establish it by a clocked reset.
        reset = 1;
        #2;
        clk = 1;
        #1;
        expected = 0;
        check();
        clk = 0;
        #1;
        tick(1);
        // Traverse every value, all carry boundaries, and 9999 -> 0000.
        for (i = 0; i < 10020; i = i + 1) tick(0);
        tick(1); // reset from a nonzero value
        for (i = 0; i < 99; i = i + 1) tick(0);
        tick(1); // reset takes priority when carry enables are asserted
        tick(1);
        tick(0);
        $display("PASS: full BCD period, carry enables, synchronous reset and reset priority");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
