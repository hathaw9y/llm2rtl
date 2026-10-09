`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic d = 0;
    logic r = 0;
    wire q;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .d(d), .r(r), .q(q));

    task automatic check(input logic want);
        begin
            if (q !== want) $fatal(1, "q=%b expected=%b at %0t", q, want, $time);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input logic reset_value, input logic data_value);
        begin
            r = reset_value;
            d = data_value;
            #2;
            check(expected);
            clk = 1;
            expected = reset_value ? 1'b0 : data_value;
            #1;
            check(expected);
            // Mutate both inputs while clock is high: neither may update q.
            r = ~reset_value;
            d = ~data_value;
            #1;
            check(expected);
            clk = 0;
            #1;
            check(expected);
        end
    endtask

    initial begin
        // First establish state; do not constrain power-up q.
        r = 1;
        d = 1;
        #2; clk = 1;
        expected = 0;
        #1; check(expected);
        clk = 0;
        #1; check(expected);
        repeat (3) begin
            cycle(0, 1);
            cycle(1, 1);
            cycle(1, 0);
            cycle(0, 0);
            cycle(0, 1);
            cycle(0, 1);
        end
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "development timeout");
    end
endmodule
