`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg a = 1'bx;
    wire q;
    TopModule dut (.clk(clk), .a(a), .q(q));

    task check(input reg expected);
        begin
            if (q !== expected)
                $fatal(1, "time=%0t expected q=%b got=%b", $time, expected, q);
        end
    endtask

    // Input transitions at the listed rising-edge timestamps take effect
    // after the clock samples the preceding input value.
    initial begin
        #0.001; check(1'bx);
        #4.999; clk = 1; a <= 0;
        #0.001; check(1'bx);
        #4.999; clk = 0;
        #0.001; check(1'bx);
        #4.999; clk = 1;
        #0.001; check(1);
        #4.999; clk = 0;
        #0.001; check(1);
        #4.999; clk = 1;
        #0.001; check(1);
        #4.999; clk = 0;
        #0.001; check(1);
        #4.999; clk = 1; a <= 1;
        #0.001; check(1);
        #4.999; clk = 0;
        #0.001; check(1);
        #4.999; clk = 1;
        #0.001; check(0);
        #4.999; clk = 0;
        #0.001; check(0);
        repeat (4) begin
            #4.999; clk = 1;
            #0.001; check(0);
            #4.999; clk = 0;
            #0.001; check(0);
        end
        // Now at 90.001 ns. Off-edge input changes distinguish a single
        // sampling register from an extra pipeline stage or combinational q.
        #1; a = 0;
        #1; check(0);
        #2.999; clk = 1;
        #0.001; check(1);
        #2; a = 1;
        #1; check(1);
        #1.999; clk = 0;
        #0.001; check(1);
        #4.999; clk = 1;
        #0.001; check(0);
        #1; a = 1'bx;
        #1; check(0);
        #2.999; clk = 0;
        #5; clk = 1;
        #0.001; check(1'bx);
        #1; a = 0;
        #1; check(1'bx);
        #2.999; clk = 0;
        #5; clk = 1;
        #0.001; check(1);
        $display("PASS waveform replay and directed edge/unknown checks");
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "timeout");
    end
endmodule
