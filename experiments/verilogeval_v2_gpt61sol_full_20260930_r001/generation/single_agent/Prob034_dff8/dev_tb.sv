`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic [7:0] d = 0;
    wire [7:0] q;
    logic [7:0] expected;
    integer i;
    TopModule dut (.clk(clk), .d(d), .q(q));

    initial begin
        #1;
        clk = 1;
        #1;
        expected = 0;
        if (q !== expected) $fatal(1, "Initial capture failed");
        for (i = 0; i < 256; i = i + 1) begin
            clk = 0;
            d = 8'(i);
            #1;
            if (q !== expected) $fatal(1, "Output changed without rising edge at %0d", i);
            clk = 1;
            expected = d;
            #1;
            if (q !== expected) $fatal(1, "Capture failed at %0d", i);
            d = ~expected;
            #1;
            if (q !== expected) $fatal(1, "Output changed while clock high at %0d", i);
            clk = 0;
            #1;
            if (q !== expected) $fatal(1, "Output changed on falling edge at %0d", i);
        end
        $display("PASS: all 256 byte values captured; inter-edge stability verified");
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Development test timed out");
    end
endmodule
