`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic ar = 0;
    logic d = 0;
    wire q;
    integer checks = 0;
    TopModule dut (.clk(clk), .ar(ar), .d(d), .q(q));

    task automatic check(input logic expected);
        begin
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "Check %0d at %0t: expected %b, got %b", checks, $time, expected, q);
        end
    endtask

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end

    initial begin
        // No reset or capture yet: the storage has no specified initialization.
        #1; check(1'bx);
        d = 1;
        #1; check(1'bx);
        // Reset assertion while clock is low must immediately clear storage.
        ar = 1;
        #1; check(0);
        ar = 0;
        #1; check(0);
        clk = 1;
        #1; check(1);
        // Data changes while clock is high must not pass through.
        d = 0;
        #1; check(1);
        clk = 0;
        #1; check(1);
        clk = 1;
        #1; check(0);
        d = 1;
        #1; check(0);
        clk = 0;
        #1; check(0);
        clk = 1;
        #1; check(1);
        // Reset assertion while clock is high is also asynchronous.
        ar = 1;
        #1; check(0);
        d = 0;
        #1; check(0);
        d = 1;
        clk = 0;
        #1; check(0);
        clk = 1;
        #1; check(0); // Reset dominates capture of d=1.
        ar = 0;
        #1; check(0); // Reset release itself does not capture.
        clk = 0;
        #1; check(0);
        clk = 1;
        #1; check(1);
        clk = 0;
        #1;
        ar = 1;
        clk = 1;
        #1; check(0); // Simultaneous assertion and rising clock.
        clk = 0;
        ar = 0;
        d = 0;
        #1; check(0);
        clk = 1;
        #1; check(0);
        $display("PASS: %0d directed flip-flop checks", checks);
        $finish;
    end
endmodule
