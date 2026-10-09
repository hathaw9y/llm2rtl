`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic [7:0] d = 8'h00;
    wire [7:0] q;
    logic [7:0] expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .areset(areset), .d(d), .q(q));

    task automatic check(input logic [7:0] want);
        begin
            checks = checks + 1;
            if (q !== want)
                $fatal(1, "Mismatch at %0t: q=%h expected=%h", $time, q, want);
        end
    endtask

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end

    initial begin
        // Establish state through asynchronous reset, with no clock edge.
        #2; areset = 1;
        #1; check(8'h00);
        d = 8'hff;
        #1; check(8'h00);
        clk = 1;
        #1; check(8'h00);
        clk = 0;
        #1; areset = 0;
        #1; check(8'h00);
        expected = 8'h00;

        // Exhaustively sample each data word. Data changes and falling
        // edges must preserve the previous sample.
        for (integer value = 0; value < 256; value = value + 1) begin
            d = value[7:0];
            #1; check(expected);
            clk = 1;
            expected = value[7:0];
            #1; check(expected);
            d = ~value[7:0];
            #1; check(expected);
            clk = 0;
            #1; check(expected);
        end

        // Reset from a nonzero value with the clock held low.
        d = 8'ha5;
        #1; clk = 1;
        #1; check(8'ha5);
        clk = 0;
        #2; areset = 1;
        #1; check(8'h00);
        areset = 0;
        #1; check(8'h00);
        clk = 1;
        #1; check(8'ha5);

        // Assert and release reset while clock is high; release alone
        // must not capture data. Keep reset active through another edge.
        areset = 1;
        #1; check(8'h00);
        d = 8'h5a;
        areset = 0;
        #1; check(8'h00);
        clk = 0;
        #1; check(8'h00);
        clk = 1;
        #1; check(8'h5a);
        clk = 0;
        areset = 1;
        #1; check(8'h00);
        d = 8'hff;
        clk = 1;
        #1; check(8'h00);
        clk = 0;
        #1; areset = 0;
        #1; check(8'h00);
        clk = 1;
        #1; check(8'hff);
        $display("PASS: %0d checks", checks);
        $finish;
    end
endmodule
