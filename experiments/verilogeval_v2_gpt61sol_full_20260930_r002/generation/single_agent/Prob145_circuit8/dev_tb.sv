`timescale 1ns/1ps
module dev_tb;
    logic clock = 0;
    logic a = 0;
    wire p, q;
    integer checks = 0;
    TopModule dut (.clock(clock), .a(a), .p(p), .q(q));

    task automatic check(input logic expected_p, input logic expected_q);
        begin
            if (p !== expected_p || q !== expected_q)
                $fatal(1, "Mismatch at %0t: p=%b q=%b expected p=%b q=%b", $time, p, q, expected_p, expected_q);
            checks = checks + 1;
        end
    endtask

    initial begin
        #500;
        $fatal(1, "Timeout");
    end

    initial begin
        clock = 1'b0; a = 1'b0; // 0 ns
        #0.001; check(1'bx, 1'bx);
        #4.999;
        clock = 1'b0; a = 1'b0; // 5 ns
        #0.001; check(1'bx, 1'bx);
        #4.999;
        clock = 1'b0; a = 1'b0; // 10 ns
        #0.001; check(1'bx, 1'bx);
        #4.999;
        clock = 1'b0; a = 1'b0; // 15 ns
        #0.001; check(1'bx, 1'bx);
        #4.999;
        clock = 1'b0; a = 1'b0; // 20 ns
        #0.001; check(1'bx, 1'bx);
        #4.999;
        clock = 1'b1; a = 1'b0; // 25 ns
        #0.001; check(1'b0, 1'bx);
        #4.999;
        clock = 1'b1; a = 1'b0; // 30 ns
        #0.001; check(1'b0, 1'bx);
        #4.999;
        clock = 1'b1; a = 1'b0; // 35 ns
        #0.001; check(1'b0, 1'bx);
        #4.999;
        clock = 1'b1; a = 1'b0; // 40 ns
        #0.001; check(1'b0, 1'bx);
        #4.999;
        clock = 1'b1; a = 1'b0; // 45 ns
        #0.001; check(1'b0, 1'bx);
        #4.999;
        clock = 1'b1; a = 1'b0; // 50 ns
        #0.001; check(1'b0, 1'bx);
        #4.999;
        clock = 1'b0; a = 1'b0; // 55 ns
        #0.001; check(1'b0, 1'b0);
        #4.999;
        clock = 1'b0; a = 1'b0; // 60 ns
        #0.001; check(1'b0, 1'b0);
        #4.999;
        clock = 1'b0; a = 1'b0; // 65 ns
        #0.001; check(1'b0, 1'b0);
        #4.999;
        clock = 1'b0; a = 1'b1; // 70 ns
        #0.001; check(1'b0, 1'b0);
        #4.999;
        clock = 1'b0; a = 1'b0; // 75 ns
        #0.001; check(1'b0, 1'b0);
        #4.999;
        clock = 1'b0; a = 1'b1; // 80 ns
        #0.001; check(1'b0, 1'b0);
        #4.999;
        clock = 1'b1; a = 1'b0; // 85 ns
        #0.001; check(1'b0, 1'b0);
        #4.999;
        clock = 1'b1; a = 1'b1; // 90 ns
        #0.001; check(1'b1, 1'b0);
        #4.999;
        clock = 1'b1; a = 1'b0; // 95 ns
        #0.001; check(1'b0, 1'b0);
        #4.999;
        clock = 1'b1; a = 1'b1; // 100 ns
        #0.001; check(1'b1, 1'b0);
        #4.999;
        clock = 1'b1; a = 1'b0; // 105 ns
        #0.001; check(1'b0, 1'b0);
        #4.999;
        clock = 1'b1; a = 1'b1; // 110 ns
        #0.001; check(1'b1, 1'b0);
        #4.999;
        clock = 1'b0; a = 1'b0; // 115 ns
        #0.001; check(1'b1, 1'b1);
        #4.999;
        clock = 1'b0; a = 1'b1; // 120 ns
        #0.001; check(1'b1, 1'b1);
        #4.999;
        clock = 1'b0; a = 1'b0; // 125 ns
        #0.001; check(1'b1, 1'b1);
        #4.999;
        clock = 1'b0; a = 1'b1; // 130 ns
        #0.001; check(1'b1, 1'b1);
        #4.999;
        clock = 1'b0; a = 1'b0; // 135 ns
        #0.001; check(1'b1, 1'b1);
        #4.999;
        clock = 1'b0; a = 1'b0; // 140 ns
        #0.001; check(1'b1, 1'b1);
        #4.999;
        clock = 1'b1; a = 1'b0; // 145 ns
        #0.001; check(1'b0, 1'b1);
        #4.999;
        clock = 1'b1; a = 1'b0; // 150 ns
        #0.001; check(1'b0, 1'b1);
        #4.999;
        clock = 1'b1; a = 1'b0; // 155 ns
        #0.001; check(1'b0, 1'b1);
        #4.999;
        clock = 1'b1; a = 1'b0; // 160 ns
        #0.001; check(1'b0, 1'b1);
        #4.999;
        clock = 1'b1; a = 1'b1; // 165 ns
        #0.001; check(1'b1, 1'b1);
        #4.999;
        clock = 1'b1; a = 1'b0; // 170 ns
        #0.001; check(1'b0, 1'b1);
        #4.999;
        clock = 1'b0; a = 1'b1; // 175 ns
        #0.001; check(1'b0, 1'b0);
        #4.999;
        clock = 1'b0; a = 1'b0; // 180 ns
        #0.001; check(1'b0, 1'b0);
        #4.999;
        clock = 1'b0; a = 1'b1; // 185 ns
        #0.001; check(1'b0, 1'b0);
        #4.999;
        clock = 1'b0; a = 1'b0; // 190 ns
        #0.001; check(1'b0, 1'b0);
        // Further directed cases: transparency, held state, and falling-edge capture.
        #4.999; clock = 1; a = 1;
        #0.001; check(1, 0);
        #1; a = 0;
        #0.001; check(0, 0);
        #1; a = 1;
        #0.001; check(1, 0);
        #1; clock = 0;
        #0.001; check(1, 1);
        #1; a = 0;
        #0.001; check(1, 1);
        #1; clock = 1;
        #0.001; check(0, 1);
        #1; clock = 0;
        #0.001; check(0, 0);
        $display("PASS waveform replay and directed checks (%0d checks)", checks);
        $finish;
    end
endmodule
