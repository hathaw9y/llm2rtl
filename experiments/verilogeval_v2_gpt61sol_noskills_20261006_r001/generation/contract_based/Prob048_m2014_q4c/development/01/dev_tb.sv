`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg d = 0;
    reg r = 0;
    wire q;
    integer checks = 0;
    TopModule dut (.clk(clk), .d(d), .r(r), .q(q));

    task check_q(input reg expected, input integer point);
        begin
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "Check %0d: q=%b expected=%b", point, q, expected);
        end
    endtask

    // Each expected value is a directed consequence of the original specification.
    task capture(input reg data_value, input reg reset_value,
                 input reg previous_value, input reg next_value, input integer point);
        begin
            d = data_value;
            r = reset_value;
            #2; check_q(previous_value, point);
            clk = 1;
            #1; check_q(next_value, point + 1);
            clk = 0;
            #1; check_q(next_value, point + 2);
        end
    endtask

    initial begin
        // No power-up value is specified; first establish q through capture.
        d = 1; r = 0;
        #2; clk = 1;
        #1; check_q(1, 1);
        clk = 0;
        #1; check_q(1, 2);

        capture(1, 1, 1, 0, 10); // Reset asserted away from edge must hold 1.
        capture(0, 1, 0, 0, 20); // Reset with d=0.
        capture(1, 1, 0, 0, 30); // Repeated reset overrides d=1.
        capture(1, 0, 0, 1, 40); // Deassert reset, capture 1.
        capture(0, 0, 1, 0, 50); // Capture 0.
        capture(1, 0, 0, 1, 60); // Consecutive changes.

        // Exercise input and reset changes while clk remains high.
        clk = 1;
        #1; check_q(1, 70);
        d = 0; r = 1;
        #2; check_q(1, 71);
        r = 0;
        #2; check_q(1, 72);
        clk = 0;
        #1; check_q(1, 73);
        capture(0, 0, 1, 0, 80);
        capture(1, 0, 0, 1, 90);
        capture(0, 1, 1, 0, 100);
        capture(0, 0, 0, 0, 110);
        $display("PASS: %0d D flip flop checks", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
