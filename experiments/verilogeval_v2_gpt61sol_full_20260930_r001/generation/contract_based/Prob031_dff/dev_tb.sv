`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic d = 1'b0;
    wire q;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .d(d), .q(q));

    task automatic check;
        if (q !== expected)
            $fatal(1, "Mismatch: q=%b expected=%b", q, expected);
        checks = checks + 1;
    endtask

    task automatic sample(input logic value);
        d = value;
        #2;
        clk = 1'b1;
        expected = value;
        #1;
        check();
        d = ~value;
        #1;
        check();
        clk = 1'b0;
        #1;
        check();
        d = value;
        #1;
        check();
    endtask

    initial begin
        sample(1'b0);
        sample(1'b1);
        sample(1'b1);
        sample(1'b0);
        sample(1'b0);
        for (integer i = 0; i < 20; i = i + 1)
            sample(i % 2 == 1);
        $display("PASS: %0d capture and hold checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Development watchdog expired");
    end
endmodule
