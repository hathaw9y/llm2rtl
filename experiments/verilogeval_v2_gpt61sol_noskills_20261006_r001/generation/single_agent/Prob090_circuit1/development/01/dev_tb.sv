`timescale 1ns/1ps
module dev_tb;
    reg a, b;
    wire q;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .q(q));

    // Set inputs at each original timestamp, then sample after delta settling.
    task sample(input reg av, input reg bv, input reg expected);
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
        sample(0, 0, 0);
        #5; sample(0, 0, 0);
        #5; sample(0, 0, 0);
        #5; sample(0, 0, 0);
        #5; sample(0, 0, 0);
        #5; sample(0, 1, 0);
        #5; sample(0, 1, 0);
        #5; sample(1, 0, 0);
        #5; sample(1, 0, 0);
        #5; sample(1, 1, 1);
        #5; sample(1, 1, 1);
        #5; sample(0, 0, 0);
        #5; sample(0, 0, 0);
        #5; sample(0, 1, 0);
        #5; sample(0, 1, 0);
        #5; sample(1, 0, 0);
        #5; sample(1, 0, 0);
        #5; sample(1, 1, 1);
        #5; sample(1, 1, 1);
        // Additional single-input transitions cover both falling/rising paths.
        #5; sample(0, 1, 0);
        #5; sample(1, 1, 1);
        #5; sample(1, 0, 0);
        #5; sample(1, 1, 1);
        $display("PASS: %0d waveform and transition checks", checks);
        $finish;
    end

    initial begin
        #150;
        $fatal(1, "Timeout");
    end
endmodule
