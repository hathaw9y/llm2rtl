`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg [7:0] d = 8'hff;
    wire [7:0] q;
    integer i;
    reg [7:0] expected;
    TopModule dut (.clk(clk), .areset(areset), .d(d), .q(q));

    task check;
        input [7:0] value;
        input [255:0] context;
        begin
            if (q !== value)
                $fatal(1, "%0s: expected %02h got %02h", context, value, q);
        end
    endtask

    initial begin
        // No requirement is imposed on q before its first specified event.
        #2; areset = 1;
        #1; check(8'h00, "async reset with clock low");
        d = 8'ha5;
        #1; clk = 1;
        #1; check(8'h00, "reset dominates rising edge");
        areset = 0;
        #1; check(8'h00, "reset release holds output");
        clk = 0;
        #1; check(8'h00, "falling edge holds output");
        for (i = 0; i < 256; i = i + 1) begin
            d = i;
            #1; check(i == 0 ? 8'h00 : (i - 1), "data change while clock low");
            clk = 1;
            #1; check(i, "positive edge captures byte");
            expected = i;
            d = ~expected;
            #1; check(expected, "data change while clock high");
            clk = 0;
            #1; check(expected, "negative edge holds byte");
        end
        // Establish a nonzero value and assert reset with clk held high.
        d = 8'h96;
        #1; clk = 1;
        #1; check(8'h96, "capture before high-clock reset");
        areset = 1;
        #1; check(8'h00, "async reset with clock high");
        d = 8'hff;
        #1; check(8'h00, "data changes under reset");
        areset = 0;
        #1; check(8'h00, "release at high clock holds zero");
        clk = 0;
        #1; clk = 1;
        #1; check(8'hff, "first rising edge after release");
        clk = 0;
        #1; clk = 1; areset = 1;
        #1; check(8'h00, "simultaneous reset and rising clock");
        clk = 0;
        #1; check(8'h00, "reset remains asserted");
        $display("PASS: asynchronous reset and all 256 byte captures verified");
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
