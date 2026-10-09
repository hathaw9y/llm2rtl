`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic [7:0] d = 8'hff;
    wire [7:0] q;
    logic [7:0] held;
    integer i;
    integer checks = 0;

    TopModule dut (.clk(clk), .areset(areset), .d(d), .q(q));

    task automatic check(input logic [7:0] expected, input string context);
        if (q !== expected)
            $fatal(1, "%s: expected %h got %h at %0t", context, expected, q, $time);
        checks = checks + 1;
    endtask

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end

    initial begin
        // No power-up assertion: original specification does not define it.
        #2; areset = 1;
        #1; check(8'h00, "asynchronous reset with clock low");
        d = 8'ha5;
        #1; clk = 1;
        #1; check(8'h00, "reset dominates rising edge");
        areset = 0;
        #1; check(8'h00, "release while clock high holds zero");
        clk = 0;
        #1; check(8'h00, "falling edge holds zero");

        // Exhaustive binary data patterns, plus hold checks at each phase.
        held = 8'h00;
        for (i = 0; i < 256; i = i + 1) begin
            d = i[7:0];
            #1; check(held, "data alone cannot change q");
            clk = 1;
            #1; check(i[7:0], "positive edge captures all eight bits");
            held = i[7:0];
            d = ~i[7:0];
            #1; check(held, "data mutation while clock high holds q");
            clk = 0;
            #1; check(held, "negative edge does not capture");
        end

        d = 8'h96;
        #1; clk = 1;
        #1; check(8'h96, "capture before active reset");
        areset = 1;
        #1; check(8'h00, "asynchronous reset with clock high");
        areset = 0;
        #1; check(8'h00, "reset release is not capture");
        clk = 0;
        #1; clk = 1;
        #1; check(8'h96, "capture resumes after reset");
        clk = 0;
        #1; areset = 1;
        #1; check(8'h00, "repeated reset assertion");
        clk = 1;
        #1; check(8'h00, "held reset at clock edge");
        $display("PASS: %0d checks", checks);
        $finish;
    end
endmodule
