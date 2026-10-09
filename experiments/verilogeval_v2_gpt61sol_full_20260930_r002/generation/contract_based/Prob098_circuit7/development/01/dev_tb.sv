`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic a = 1'bx;
    wire q;
    integer checks = 0;
    TopModule dut (.clk(clk), .a(a), .q(q));
    always #5 clk = ~clk;

    task automatic check(input logic expected);
        begin
            if (q !== expected)
                $fatal(1, "Mismatch at %0t: a=%b q=%b expected=%b", $time, a, q, expected);
            checks = checks + 1;
        end
    endtask

    // Preserve the original simultaneous timestamps. Nonblocking stimulus
    // expresses input changes after sampling, as implied by q in the table.
    initial begin
        #5 a <= 1'b0;
        #30 a <= 1'b1;
    end

    initial begin
        #0.001; check(1'bx);             // 0 ns
        #5; check(1'bx);                // 5 ns
        #5; check(1'bx);                // 10 ns
        #5; check(1'b1);                // 15 ns
        #5; check(1'b1);                // 20 ns
        #5; check(1'b1);                // 25 ns
        #5; check(1'b1);                // 30 ns
        #5; check(1'b1);                // 35 ns
        #5; check(1'b1);                // 40 ns
        #5; check(1'b0);                // 45 ns
        #5; check(1'b0);                // 50 ns
        #5; check(1'b0);                // 55 ns
        #5; check(1'b0);                // 60 ns
        #5; check(1'b0);                // 65 ns
        #5; check(1'b0);                // 70 ns
        #5; check(1'b0);                // 75 ns
        #5; check(1'b0);                // 80 ns
        #5; check(1'b0);                // 85 ns
        #5; check(1'b0);                // 90 ns

        // Off-edge changes must hold q until the next rising edge.
        #1 a = 1'b0;
        #1 check(1'b0);
        @(posedge clk); #0.001; check(1'b1);
        @(negedge clk); #0.001; check(1'b1);
        #1 a = 1'b1;
        #1 check(1'b1);
        @(posedge clk); #0.001; check(1'b0);
        @(negedge clk); #0.001; check(1'b0);
        #1 a = 1'bx;
        #1 check(1'b0);
        @(posedge clk); #0.001; check(1'bx);
        @(negedge clk); #0.001; check(1'bx);
        #1 a = 1'b0;
        #1 check(1'bx);
        @(posedge clk); #0.001; check(1'b1);
        @(negedge clk); #0.001; check(1'b1);
        #1 a = 1'b1;
        @(posedge clk); #0.001; check(1'b0);
        $display("PASS original waveform and directed sampling checks (%0d comparisons)", checks);
        $finish;
    end
    initial begin
        #300;
        $fatal(1, "Timeout");
    end
endmodule
