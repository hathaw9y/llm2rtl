`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg ar = 0;
    reg d = 0;
    wire q;
    integer checks = 0;
    integer i;
    TopModule dut(.clk(clk), .ar(ar), .d(d), .q(q));

    task expect_q(input reg expected, input [255:0] context);
        begin
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "%0s: expected q=%b, got %b", context, expected, q);
        end
    endtask

    initial begin
        // No power-up value is specified. Establish state using reset.
        #2; d = 1; ar = 1;
        #1; expect_q(0, "asynchronous reset clock low");
        ar = 0;
        #1; expect_q(0, "reset release holds state");
        clk = 1;
        #1; expect_q(1, "positive edge captures one");
        d = 0;
        #1; expect_q(1, "data change while clock high");
        clk = 0;
        #1; expect_q(1, "negative edge holds state");
        clk = 1;
        #1; expect_q(0, "positive edge captures zero");
        clk = 0; d = 1;
        #1; expect_q(0, "data change while clock low");
        clk = 1;
        #1; expect_q(1, "capture before asynchronous reset");
        ar = 1;
        #1; expect_q(0, "asynchronous reset clock high");
        ar = 0;
        #1; expect_q(0, "release while high does not capture");
        clk = 0; ar = 1;
        #1; expect_q(0, "reset reassertion");
        clk = 1;
        #1; expect_q(0, "reset dominates one at rising edge");
        clk = 0; d = 0;
        #1; clk = 1;
        #1; expect_q(0, "reset held through another edge");
        clk = 0; ar = 0;
        for (i = 0; i < 16; i = i + 1) begin
            d = (i % 3 != 0);
            #2; clk = 1;
            #1; expect_q((i % 3 != 0), "repeated data capture");
            d = ~d;
            #1; expect_q((i % 3 != 0), "between-edge storage");
            clk = 0;
            #1; expect_q((i % 3 != 0), "falling-edge storage");
        end
        // Coincident assertion must dominate data capture.
        d = 1; ar = 1; clk = 1;
        #1; expect_q(0, "coincident reset and positive edge");
        $display("PASS: %0d D flip flop checks", checks);
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
