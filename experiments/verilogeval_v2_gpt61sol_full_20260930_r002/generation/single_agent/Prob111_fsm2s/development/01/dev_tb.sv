`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic j = 0;
    logic k = 0;
    wire out;
    logic expected;
    integer checks = 0;
    integer s, r, a, b, n;
    TopModule dut (.clk(clk), .reset(reset), .j(j), .k(k), .out(out));

    task automatic check_output;
        begin
            if (out !== expected)
                $fatal(1, "Mismatch check=%0d reset=%b j=%b k=%b expected=%b out=%b", checks, reset, j, k, expected, out);
            checks = checks + 1;
        end
    endtask

    // Inputs change while the clock is low. Check Moore stability before
    // the rising edge, then compare the state after nonblocking updates.
    task automatic cycle(input logic rst, input logic ji, input logic ki);
        begin
            clk = 0;
            reset = rst;
            j = ji;
            k = ki;
            #2;
            check_output();
            if (rst) expected = 0;
            else if (expected == 0) expected = ji;
            else expected = !ki;
            clk = 1;
            #1;
            check_output();
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        // No pre-reset state is specified: establish a known state by a
        // synchronous reset edge before comparing outputs.
        reset = 1;
        #2;
        clk = 1;
        expected = 0;
        #1;
        check_output();
        clk = 0;
        #1;
        for (s = 0; s < 2; s = s + 1)
            for (r = 0; r < 2; r = r + 1)
                for (a = 0; a < 2; a = a + 1)
                    for (b = 0; b < 2; b = b + 1) begin
                        cycle(1, 1, 1);
                        cycle(0, s == 1, 0);
                        cycle(r == 1, a == 1, b == 1);
                    end

        // Reset pulses without a rising edge must leave ON unchanged.
        cycle(0, 1, 0);
        reset = 1;
        j = 0;
        k = 1;
        #2;
        check_output();
        reset = 0;
        #2;
        check_output();
        // Even changes while clk is high cannot alter a Moore output.
        cycle(0, 0, 0);
        clk = 1;
        #1;
        check_output();
        reset = 1;
        j = 1;
        k = 1;
        #2;
        check_output();
        clk = 0;
        #1;
        cycle(1, 1, 1);
        for (n = 0; n < 64; n = n + 1)
            cycle(0, 1, 1);
        for (n = 0; n < 16; n = n + 1)
            cycle(0, 0, 0);
        $display("PASS: %0d FSM output checks", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
