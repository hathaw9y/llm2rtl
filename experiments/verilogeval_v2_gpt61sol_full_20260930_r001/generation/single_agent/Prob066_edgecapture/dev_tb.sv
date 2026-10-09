`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [31:0] in = 0;
    wire [31:0] out;
    logic [31:0] expected = 0;
    logic [31:0] previous = 0;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));
    always #5 clk = ~clk;
    task automatic step(input logic rst, input logic [31:0] value);
        @(negedge clk);
        reset = rst;
        in = value;
        @(posedge clk);
        if (rst) expected = 0;
        else begin
            for (integer bit_idx = 0; bit_idx < 32; bit_idx = bit_idx + 1)
                if (previous[bit_idx] && !value[bit_idx]) expected[bit_idx] = 1;
        end
        previous = value;
        #1;
        checks = checks + 1;
        if (out !== expected)
            $fatal(1, "FAIL check %0d: actual=%h expected=%h", checks, out, expected);
    endtask
    initial begin
        step(1, 0);
        step(0, 32'hffffffff);
        step(0, 32'haaaaaaaa);
        step(0, 32'hffffffff);
        step(0, 32'h55555555);
        step(0, 0);
        step(1, 32'hffffffff);
        step(0, 0);
        step(1, 0);
        for (integer b = 0; b < 32; b = b + 1) begin
            step(0, 32'b1 << b);
            step(0, 0);
        end
        for (integer n = 0; n < 400; n = n + 1)
            step((n % 23) == 0, $urandom);
        $display("PASS: %0d checked cycles", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL timeout");
    end
endmodule
