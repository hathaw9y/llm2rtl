`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic reset = 1'b0;
    logic [7:0] d = 8'h00;
    wire [7:0] q;
    logic [7:0] expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .d(d), .q(q));

    task automatic check_q;
        begin
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "FAIL check %0d: q=%h expected=%h", checks, q, expected);
        end
    endtask

    task automatic cycle(input logic rst, input logic [7:0] value);
        begin
            reset = rst;
            d = value;
            #1; check_q();
            clk = 1'b1;
            #1; check_q();
            clk = 1'b0;
            expected = rst ? 8'h34 : value;
            #1; check_q();
        end
    endtask

    initial begin
        // Establish the first known output through a synchronous reset edge.
        reset = 1'b1;
        d = 8'hff;
        #1; clk = 1'b1;
        #1; clk = 1'b0;
        expected = 8'h34;
        #1; check_q();
        for (integer i = 0; i < 256; i = i + 1)
            cycle(1'b0, 8'(i));
        for (integer i = 0; i < 256; i = i + 1)
            cycle(1'b1, 8'(i));
        cycle(1'b0, 8'ha5);
        // A reset pulse entirely between falling edges must leave q alone.
        reset = 1'b1;
        d = 8'h5a;
        #1; check_q();
        clk = 1'b1;
        #1; check_q();
        reset = 1'b0;
        #1; check_q();
        clk = 1'b0;
        expected = 8'h5a;
        #1; check_q();
        cycle(1'b1, 8'h00);
        cycle(1'b0, 8'h00);
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
