`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic ena = 0;
    logic [1:0] amount = 0;
    logic [63:0] data = 0;
    wire [63:0] q;
    logic signed [63:0] expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .load(load), .ena(ena), .amount(amount), .data(data), .q(q));
    always #5 clk = ~clk;
    task automatic step(input logic l, input logic e, input logic [1:0] a, input logic [63:0] d);
        logic [63:0] before_q;
        begin
            @(negedge clk);
            before_q = q;
            load = l; ena = e; amount = a; data = d;
            #1;
            if (q !== before_q) $fatal(1, "Output changed between rising edges");
            if (l) expected = d;
            else if (e) begin
                case (a)
                    0: expected = expected << 1;
                    1: expected = expected << 8;
                    2: expected = expected >>> 1;
                    3: expected = expected >>> 8;
                endcase
            end
            @(posedge clk);
            #1;
            if (q !== expected) $fatal(1, "Mismatch check=%0d got=%h expected=%h", checks, q, expected);
            checks = checks + 1;
        end
    endtask
    initial begin
        step(1, 0, 0, 64'h8000000000000001);
        for (integer a = 0; a < 4; a = a + 1) begin
            step(1, 1, a[1:0], 64'h8123456789abcdef);
            step(0, 0, a[1:0], 64'hffffffffffffffff);
            step(0, 1, a[1:0], 0);
            step(1, 0, a[1:0], 64'h7123456789abcdef);
            step(0, 1, a[1:0], 0);
        end
        step(1, 1, 0, 64'hffffffffffffffff);
        repeat (70) step(0, 1, 2, 0);
        repeat (70) step(0, 1, 0, 0);
        for (integer i = 0; i < 1000; i = i + 1)
            step($urandom_range(0, 1), $urandom_range(0, 1), $urandom_range(0, 3), {$urandom, $urandom});
        $display("PASS: %0d cycle checks", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Testbench timeout");
    end
endmodule
