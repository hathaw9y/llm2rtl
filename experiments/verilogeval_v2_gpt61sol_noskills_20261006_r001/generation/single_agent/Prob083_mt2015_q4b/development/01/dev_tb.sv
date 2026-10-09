`timescale 1ns/1ps
module dev_tb;
    reg x, y;
    wire z;
    integer checks = 0;
    TopModule dut (.x(x), .y(y), .z(z));

    task sample;
        input sx, sy, expected;
        begin
            x = sx;
            y = sy;
            // Check after the combinational delta cycle at the same timestamp.
            #0;
            if (z !== expected)
                $fatal(1, "Mismatch at %0t: x=%b y=%b z=%b expected=%b",
                       $time, x, y, z, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
             sample(0, 0, 1); // 0 ns
        #5; sample(0, 0, 1); // 5 ns
        #5; sample(0, 0, 1); // 10 ns
        #5; sample(0, 0, 1); // 15 ns
        #5; sample(0, 0, 1); // 20 ns
        #5; sample(1, 0, 0); // 25 ns
        #5; sample(1, 0, 0); // 30 ns
        #5; sample(0, 1, 0); // 35 ns
        #5; sample(0, 1, 0); // 40 ns
        #5; sample(1, 1, 1); // 45 ns
        #5; sample(1, 1, 1); // 50 ns
        #5; sample(0, 0, 1); // 55 ns
        #5; sample(0, 1, 0); // 60 ns
        #5; sample(0, 1, 0); // 65 ns
        #5; sample(1, 1, 1); // 70 ns
        #5; sample(0, 1, 0); // 75 ns
        #5; sample(0, 1, 0); // 80 ns
        #5; sample(0, 1, 0); // 85 ns
        #5; sample(1, 0, 0); // 90 ns
        // Independent truth table cases after the original waveform.
        #5; sample(0, 0, 1);
        #5; sample(0, 1, 0);
        #5; sample(1, 0, 0);
        #5; sample(1, 1, 1);
        $display("PASS: %0d waveform and truth table checks", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
