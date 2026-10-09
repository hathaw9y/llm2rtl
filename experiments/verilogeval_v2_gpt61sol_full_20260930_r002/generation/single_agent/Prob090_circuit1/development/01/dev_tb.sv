`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire q;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .q(q));

    // Drive at the original timestamps; sample after one delta cycle.
    task automatic sample(input logic av, input logic bv, input logic expected);
        begin
            a = av;
            b = bv;
            #0;
            if (q !== expected)
                $fatal(1, "Mismatch at %0t: a=%b b=%b q=%b expected=%b", $time, a, b, q, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        sample(0, 0, 0);          // 0 ns
        #5 sample(0, 0, 0);      // 5 ns
        #5 sample(0, 0, 0);      // 10 ns
        #5 sample(0, 0, 0);      // 15 ns
        #5 sample(0, 0, 0);      // 20 ns
        #5 sample(0, 1, 0);      // 25 ns
        #5 sample(0, 1, 0);      // 30 ns
        #5 sample(1, 0, 0);      // 35 ns
        #5 sample(1, 0, 0);      // 40 ns
        #5 sample(1, 1, 1);      // 45 ns
        #5 sample(1, 1, 1);      // 50 ns
        #5 sample(0, 0, 0);      // 55 ns
        #5 sample(0, 0, 0);      // 60 ns
        #5 sample(0, 1, 0);      // 65 ns
        #5 sample(0, 1, 0);      // 70 ns
        #5 sample(1, 0, 0);      // 75 ns
        #5 sample(1, 0, 0);      // 80 ns
        #5 sample(1, 1, 1);      // 85 ns
        #5 sample(1, 1, 1);      // 90 ns
        // Additional single-input transitions to cover falling/rising boundaries.
        #5 sample(1, 0, 0);
        #5 sample(1, 1, 1);
        #5 sample(0, 1, 0);
        #5 sample(1, 1, 1);
        #5 sample(0, 0, 0);
        $display("PASS: %0d waveform and boundary checks", checks);
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
