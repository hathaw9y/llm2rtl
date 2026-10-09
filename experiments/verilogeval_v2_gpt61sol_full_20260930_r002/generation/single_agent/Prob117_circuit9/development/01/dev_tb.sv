`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic a = 1'b1;
    wire [2:0] q;
    integer i;
    integer expected;
    TopModule dut (.clk(clk), .a(a), .q(q));

    task automatic check(input logic [2:0] want);
        if (q !== want)
            $fatal(1, "time=%0t expected=%b actual=%b", $time, want, q);
    endtask

    // Replay each original timestamp; inspect after nonblocking updates.
    initial begin
        #0.001;
        check(3'bxxx);
        for (i = 1; i <= 18; i = i + 1) begin
            #4.999;
            clk = ~clk;
            if (i == 9) a <= 1'b0;
            #0.001;
            case (i)
                1,2,3,4,5,6,7,8,9,10: check(3'd4);
                11,12: check(3'd5);
                13,14: check(3'd6);
                15,16: check(3'd0);
                17,18: check(3'd1);
            endcase
        end

        // Continue through repeated wraps; verify both edges and midcycle holds.
        expected = 1;
        repeat (20) begin
            #4.999;
            clk = 1'b1;
            if (expected == 6) expected = 0;
            else expected = expected + 1;
            #0.001;
            check(expected[2:0]);
            #4.999;
            clk = 1'b0;
            #0.001;
            check(expected[2:0]);
        end

        // Input assertion between edges must wait until the rising edge.
        #1;
        a = 1'b1;
        #1;
        check(expected[2:0]);
        #2.999;
        clk = 1'b1;
        #0.001;
        check(3'd4);
        repeat (3) begin
            #4.999; clk = 1'b0;
            #0.001; check(3'd4);
            #4.999; clk = 1'b1;
            #0.001; check(3'd4);
        end
        #4.999; clk = 1'b0;
        #0.001; check(3'd4);
        #1; a = 1'b0;
        #1; check(3'd4);
        #2.999; clk = 1'b1;
        #0.001; check(3'd5);
        $display("PASS waveform replay, initial unknown, modulo-7 wrap, synchronous load and hold checks");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
