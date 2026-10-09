`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic [7:0] d;
    wire [7:0] q;
    logic [7:0] expected;
    integer captures = 0;

    TopModule dut (.clk(clk), .d(d), .q(q));

    task automatic check(input logic [7:0] value);
        if (q !== value) begin
            $fatal(1, "FAIL: q=%b expected=%b", q, value);
        end
    endtask

    task automatic cycle(input logic [7:0] value);
        d = value;
        #1;
        if (captures != 0) check(expected);
        clk = 1'b1;
        expected = value;
        #1;
        check(expected);
        captures = captures + 1;
        d = ~value;
        #1;
        check(expected);
        clk = 1'b0;
        #1;
        check(expected);
    endtask

    initial begin
        for (integer i = 0; i < 256; i = i + 1)
            cycle(8'(i));
        cycle(8'bx01x1010);
        cycle(8'bz10z0101);
        cycle(8'h5a);
        $display("PASS: %0d captures; rising-edge capture and between-edge hold verified", captures);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
