`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [7:0] d = 0;
    wire [7:0] q;
    logic [7:0] expected;
    integer checks = 0;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .d(d), .q(q));

    task automatic check_q;
        if (q !== expected)
            $fatal(1, "FAIL check %0d: q=%h expected=%h", checks, q, expected);
        checks = checks + 1;
    endtask

    task automatic cycle(input logic rst, input logic [7:0] data);
        reset = rst;
        d = data;
        #2;
        check_q();
        clk = 1;
        expected = rst ? 8'h00 : data;
        #1;
        check_q();
        d = ~data;
        reset = ~rst;
        #1;
        check_q();
        clk = 0;
        #1;
        check_q();
    endtask

    initial begin
        #1;
        reset = 1;
        d = 8'hff;
        #1;
        clk = 1;
        expected = 8'h00;
        #1;
        check_q();
        clk = 0;
        #1;
        for (i = 0; i < 256; i = i + 1)
            cycle(0, 8'(i));
        for (i = 0; i < 256; i = i + 1)
            cycle(1, 8'(i));
        cycle(0, 8'ha5);
        cycle(1, 8'h5a);
        cycle(0, 8'hff);
        $display("PASS: %0d checks; exhaustive capture/reset and edge/hold behavior", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
