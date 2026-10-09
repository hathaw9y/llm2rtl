`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [7:0] in = 0;
    wire done;
    integer pending = 0;
    integer checks = 0;
    logic expected;
    logic [15:0] rng = 16'hac91;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .done(done));
    always #5 clk = ~clk;

    task automatic step(input logic rst, input logic [7:0] value);
        @(negedge clk);
        reset = rst;
        in = value;
        @(posedge clk);
        expected = 0;
        if (rst) pending = 0;
        else if (pending == 2) begin
            expected = 1;
            pending = 0;
        end else if (pending != 0) pending = pending + 1;
        else if (value[3]) pending = 1;
        #1;
        checks = checks + 1;
        if (done !== expected)
            $fatal(1, "FAIL check=%0d reset=%b in=%h done=%b expected=%b", checks, rst, value, done, expected);
    endtask

    initial begin
        step(1, 8'hff);
        repeat (5) step(0, 8'h00);
        step(0, 8'h08);
        step(0, 8'h00);
        step(0, 8'h00);
        repeat (12) step(0, 8'hff);
        step(1, 8'h00);
        step(0, 8'h08);
        step(1, 8'h08);
        step(0, 8'h08);
        step(0, 8'h08);
        step(1, 8'h08);
        for (integer i = 0; i < 1000; i = i + 1) begin
            rng = {rng[14:0], rng[15] ^ rng[13] ^ rng[12] ^ rng[10]};
            step((i % 37) == 0, rng[7:0]);
        end
        $display("PASS: %0d checked cycles", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "FAIL: timeout");
    end
endmodule
