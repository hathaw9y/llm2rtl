`timescale 1ns/1ps
module dev_tb;
    reg d;
    reg ena;
    wire q;
    integer checks = 0;
    TopModule dut (.d(d), .ena(ena), .q(q));

    task expect_q(input reg expected);
        begin
            #1;
            if (q !== expected)
                $fatal(1, "Latch mismatch at %0t: d=%b ena=%b q=%b expected=%b", $time, d, ena, q, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        d = 0; ena = 0; expect_q(1'bx);
        d = 1; expect_q(1'bx);
        d = 0; expect_q(1'bx);
        ena = 1; expect_q(0);
        d = 1; expect_q(1);
        d = 0; expect_q(0);
        d = 1; expect_q(1);
        ena = 0; expect_q(1);
        d = 0; expect_q(1);
        d = 1; expect_q(1);
        d = 0; expect_q(1);
        ena = 1; expect_q(0);
        ena = 0; expect_q(0);
        d = 1; expect_q(0);
        d = 0; expect_q(0);
        d = 1; ena = 1; expect_q(1);
        d = 0; ena = 0; expect_q(1);
        ena = 1; expect_q(0);
        d = 1'bx; expect_q(1'bx);
        ena = 0; d = 1; expect_q(1'bx);
        ena = 1; expect_q(1);
        d = 0; expect_q(0);
        ena = 0; d = 1; expect_q(0);
        #5; expect_q(0);
        $display("PASS: %0d D latch checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
