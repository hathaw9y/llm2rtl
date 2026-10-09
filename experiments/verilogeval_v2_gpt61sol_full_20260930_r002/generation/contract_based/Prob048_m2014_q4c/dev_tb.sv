`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic d = 1'b0;
    logic r = 1'b0;
    wire q;
    integer checks = 0;
    TopModule dut (.clk(clk), .d(d), .r(r), .q(q));

    task automatic expect_q(input logic expected, input string context_msg);
        if (q !== expected)
            $fatal(1, "%s: expected q=%b, got %b", context_msg, expected, q);
        checks = checks + 1;
    endtask

    // Truth table oracle from the original D flip flop specification.
    task automatic cycle(input logic reset_value, input logic data_value);
        logic before_edge;
        begin
            before_edge = q;
            r = reset_value;
            d = data_value;
            #2;
            expect_q(before_edge, "input changes while clock low must hold");
            clk = 1'b1;
            #1;
            if (reset_value == 1'b1)
                expect_q(1'b0, "rising edge reset priority");
            else
                expect_q(data_value, "rising edge data capture");
            before_edge = q;
            d = ~data_value;
            r = ~reset_value;
            #2;
            expect_q(before_edge, "input changes while clock high must hold");
            clk = 1'b0;
            #1;
            expect_q(before_edge, "falling edge must hold");
        end
    endtask

    initial begin
        // No constraint on q before its first sampling edge.
        d = 1'b1;
        r = 1'b0;
        #2; clk = 1'b1;
        #1; expect_q(1'b1, "first data capture without reset");
        // Assert reset between edges while q is one: it must not clear yet.
        r = 1'b1;
        #2; expect_q(1'b1, "reset assertion is synchronous");
        clk = 1'b0;
        #1; expect_q(1'b1, "reset does not act on falling edge");
        #2; clk = 1'b1;
        #1; expect_q(1'b0, "reset sampled at rising edge");
        r = 1'b0;
        #2; expect_q(1'b0, "reset deassertion does not capture data");
        clk = 1'b0;
        #1; expect_q(1'b0, "falling edge after reset holds");
        cycle(1'b0, 1'b0);
        cycle(1'b0, 1'b1);
        cycle(1'b0, 1'b1);
        cycle(1'b0, 1'b0);
        cycle(1'b1, 1'b1);
        cycle(1'b1, 1'b0);
        cycle(1'b1, 1'b1);
        cycle(1'b0, 1'b1);
        cycle(1'b0, 1'b0);
        $display("PASS: synchronous reset D flip flop, %0d checks", checks);
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
