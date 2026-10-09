`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg slowena = 0;
    wire [3:0] q;
    integer expected;
    integer cycles = 0;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .slowena(slowena), .q(q));
    always #5 clk = ~clk;

    task step(input reg r, input reg en);
        reg [3:0] before_edge;
        begin
            @(negedge clk);
            before_edge = q;
            reset = r;
            slowena = en;
            #1;
            if (q !== before_edge)
                $fatal(1, "Output changed between positive edges");
            @(posedge clk);
            if (r) expected = 0;
            else if (en) expected = (expected + 1) % 10;
            #1;
            cycles = cycles + 1;
            if (q !== expected[3:0])
                $fatal(1, "Cycle %0d: expected %0d got %b", cycles, expected, q);
        end
    endtask

    initial begin
        expected = 0;
        step(1, 0);
        step(0, 0);
        for (i = 0; i < 9; i = i + 1) step(0, 1);
        repeat (4) step(0, 0);
        step(0, 1);
        repeat (30) step(0, 1);
        step(1, 1);
        step(1, 0);
        for (i = 0; i < 100; i = i + 1)
            step((i % 23) == 17, (i % 4) != 0);
        step(0, 1);
        step(1, 0);
        repeat (5) step(0, 0);
        $display("PASS: synchronous reset, enable hold, increment and decade wrap (%0d cycles)", cycles);
        $finish;
    end
    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
