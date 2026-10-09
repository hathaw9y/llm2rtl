`timescale 1ns/1ps
module dev_tb;
    reg a, b;
    wire q;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .q(q));

    task check_sample(input reg expected);
        begin
            // Settle continuous assignments without shifting waveform time.
            #0;
            if (q !== expected)
                $fatal(1, "At %0t: a=%b b=%b q=%b expected=%b", $time, a, b, q, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        a=0; b=0; check_sample(0); // 0 ns
        #5; check_sample(0); // 5 ns
        #5; check_sample(0); // 10 ns
        #5; check_sample(0); // 15 ns
        #5; check_sample(0); // 20 ns
        #5; a=0; b=1; check_sample(0); // 25 ns
        #5; check_sample(0); // 30 ns
        #5; a=1; b=0; check_sample(0); // 35 ns
        #5; check_sample(0); // 40 ns
        #5; a=1; b=1; check_sample(1); // 45 ns
        #5; check_sample(1); // 50 ns
        #5; a=0; b=0; check_sample(0); // 55 ns
        #5; check_sample(0); // 60 ns
        #5; a=0; b=1; check_sample(0); // 65 ns
        #5; check_sample(0); // 70 ns
        #5; a=1; b=0; check_sample(0); // 75 ns
        #5; check_sample(0); // 80 ns
        #5; a=1; b=1; check_sample(1); // 85 ns
        #5; check_sample(1); // 90 ns
        if (checks != 19) $fatal(1, "Missing waveform samples");
        $display("PASS: all 19 original waveform samples checked");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
