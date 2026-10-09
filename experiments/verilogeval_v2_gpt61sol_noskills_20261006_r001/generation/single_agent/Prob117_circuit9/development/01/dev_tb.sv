`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg a = 1;
    wire [2:0] q;
    integer step;
    integer expected;
    TopModule dut (.clk(clk), .a(a), .q(q));

    task check(input [2:0] want);
        begin
            if (q !== want)
                $fatal(1, "At %0t: q=%b expected=%b", $time, q, want);
        end
    endtask

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end

    initial begin
        #0.001;
        check(3'bxxx);
        // Replay every original timestamp. At 45 ns the input changes
        // after the rising-edge sampling phase (nonblocking stimulus).
        for (step = 1; step <= 18; step = step + 1) begin
            #4.999;
            clk = ~clk;
            if (step == 9) a <= 0;
            #0.001;
            case (step)
                1,2,3,4,5,6,7,8,9,10: check(3'd4);
                11,12: check(3'd5);
                13,14: check(3'd6);
                15,16: check(3'd0);
                17,18: check(3'd1);
            endcase
        end
        // Continue through multiple complete modulo-seven periods.
        expected = 1;
        repeat (21) begin
            #4.999; clk = 1;
            expected = (expected + 1) % 7;
            #0.001; check(expected);
            #4.999; clk = 0;
            #0.001; check(expected);
        end
        // Input changes between edges must not change q immediately.
        #1; a = 1;
        #0.001; check(expected);
        #3.998; clk = 1;
        #0.001; check(3'd4);
        #4.999; clk = 0;
        #0.001; check(3'd4);
        #4.999; clk = 1;
        #0.001; check(3'd4);
        #4.999; clk = 0;
        #1; a = 0;
        #0.001; check(3'd4);
        #3.999; clk = 1;
        #0.001; check(3'd5);
        $display("PASS original waveform, initial unknown, modulo-seven wrap, synchronous load and hold");
        $finish;
    end
endmodule
