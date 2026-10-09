`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [2:0] ena;
    wire [15:0] q;
    integer expected_count = 0;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .ena(ena), .q(q));
    always #5 clk = ~clk;

    task automatic check_count(input integer count);
        reg [15:0] expected_q;
        reg [2:0] expected_ena;
        begin
            expected_q[3:0] = count % 10;
            expected_q[7:4] = (count / 10) % 10;
            expected_q[11:8] = (count / 100) % 10;
            expected_q[15:12] = (count / 1000) % 10;
            expected_ena[0] = (count % 10 == 9);
            expected_ena[1] = (count % 100 == 99);
            expected_ena[2] = (count % 1000 == 999);
            if (q !== expected_q || ena !== expected_ena)
                $fatal(1, "count=%0d q=%h expected=%h ena=%b expected=%b", count, q, expected_q, ena, expected_ena);
        end
    endtask

    task automatic tick;
        begin
            @(posedge clk);
            if (reset) expected_count = 0;
            else expected_count = (expected_count + 1) % 10000;
            #1;
            check_count(expected_count);
        end
    endtask

    initial begin
        // Establish state using a clocked reset; no initial state is specified.
        #2 reset = 1;
        tick();
        tick();
        @(negedge clk);
        reset = 0;
        for (i = 0; i < 10025; i = i + 1) tick();
        // Assert reset between rising edges and check it has no asynchronous effect.
        @(negedge clk);
        #1 reset = 1;
        #1 check_count(expected_count);
        tick();
        tick();
        @(negedge clk);
        reset = 0;
        for (i = 0; i < 137; i = i + 1) tick();
        // A pulse with no rising clock edge must not reset the counter.
        @(negedge clk);
        #1 reset = 1;
        #1 check_count(expected_count);
        #1 reset = 0;
        tick();
        $display("PASS full BCD cycle, carry enables, rollover, synchronous reset");
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
