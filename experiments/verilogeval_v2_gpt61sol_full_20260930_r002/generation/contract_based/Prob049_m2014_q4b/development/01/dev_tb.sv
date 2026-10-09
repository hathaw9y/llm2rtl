`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic ar = 0;
    logic d = 0;
    wire q;
    integer checks = 0;
    TopModule dut (.clk(clk), .ar(ar), .d(d), .q(q));

    task automatic expect_q(input logic expected, input string reason);
        begin
            if (q !== expected)
                $fatal(1, "%s: expected q=%b, observed %b", reason, expected, q);
            checks = checks + 1;
        end
    endtask

    initial begin
        #2; ar = 1; #1; expect_q(0, "asynchronous initial clear without clock");
        d = 1; #1; expect_q(0, "data does not bypass reset");
        clk = 1; #1; expect_q(0, "reset dominates rising clock");
        ar = 0; #1; expect_q(0, "release does not capture data");
        clk = 0; #1; expect_q(0, "falling clock holds output");
        clk = 1; #1; expect_q(1, "rising clock captures one");
        d = 0; #1; expect_q(1, "data change while clock high holds");
        ar = 1; #1; expect_q(0, "reset assertion while clock high clears");
        ar = 0; d = 1; #1; expect_q(0, "release while high holds");
        clk = 0; #1; expect_q(0, "falling edge after release holds");
        clk = 1; #1; expect_q(1, "capture after reset release");
        clk = 0; #1; d = 0; #1; expect_q(1, "data change while low holds");
        clk = 1; #1; expect_q(0, "rising clock captures zero");
        clk = 0; d = 1; #1;
        clk = 1; #1; expect_q(1, "second capture of one");
        clk = 0; #1; ar = 1; #1; expect_q(0, "reset assertion while low clears");
        d = 0; #1; d = 1; #1; expect_q(0, "asserted reset holds across data changes");
        clk = 1; #1; expect_q(0, "asserted reset prevents capture");
        clk = 0; ar = 0; #1; expect_q(0, "release while low holds");
        clk = 1; #1; expect_q(1, "final rising edge capture");
        $display("PASS: %0d directed D flip flop checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
