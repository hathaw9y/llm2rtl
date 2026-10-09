`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic a = 1;
    wire [2:0] q;
    integer expected;
    TopModule dut (.clk(clk), .a(a), .q(q));
    always #5 clk = ~clk;
    task automatic check(input integer value);
        if (q !== value[2:0])
            $fatal(1, "Expected %0d, got %0d at %0t", value, q, $time);
    endtask
    initial begin
        #1;
        if (q !== 3'bxxx) $fatal(1, "Unexpected initialization");
        repeat (5) begin
            @(posedge clk); #1; check(4);
        end
        // Change after the 45 ns edge to resolve coincident waveform events.
        a = 0;
        expected = 4;
        repeat (21) begin
            @(negedge clk); #1; check(expected);
            @(posedge clk); #1;
            expected = (expected + 1) % 7;
            check(expected);
        end
        @(negedge clk); a = 1;
        #1; check(expected);
        @(posedge clk); #1; check(4);
        @(negedge clk); a = 0;
        @(posedge clk); #1; check(5);
        @(negedge clk); a = 1;
        @(posedge clk); #1; check(4);
        $display("PASS: synchronous load, modulo-7 count, wrap and edge stability");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
