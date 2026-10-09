`timescale 1ns/1ps
module dev_tb;
    reg x, y;
    wire z;
    integer checks = 0;
    TopModule dut (.x(x), .y(y), .z(z));

    // B's expected values are taken directly from the waveform.
    // Combine them with the specified A equation and gate network.
    task waveform_row(input reg xv, yv, bv);
        reg av, expected;
        begin
            x = xv;
            y = yv;
            av = (xv ^ yv) & xv;
            expected = (av | bv) ^ (av & bv);
            #0.001;
            if (z !== expected)
                $fatal(1, "Waveform mismatch at %t: x=%b y=%b z=%b expected=%b",
                       $time, x, y, z, expected);
            checks = checks + 1;
            #4.999;
        end
    endtask

    task truth_row(input reg xv, yv, expected);
        begin
            x = xv; y = yv;
            #1;
            if (z !== expected)
                $fatal(1, "Truth table mismatch: x=%b y=%b z=%b expected=%b",
                       x, y, z, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        waveform_row(0, 0, 1); // 0 ns
        waveform_row(0, 0, 1); // 5 ns
        waveform_row(0, 0, 1); // 10 ns
        waveform_row(0, 0, 1); // 15 ns
        waveform_row(0, 0, 1); // 20 ns
        waveform_row(1, 0, 0); // 25 ns
        waveform_row(1, 0, 0); // 30 ns
        waveform_row(0, 1, 0); // 35 ns
        waveform_row(0, 1, 0); // 40 ns
        waveform_row(1, 1, 1); // 45 ns
        waveform_row(1, 1, 1); // 50 ns
        waveform_row(0, 0, 1); // 55 ns
        waveform_row(0, 1, 0); // 60 ns
        waveform_row(0, 1, 0); // 65 ns
        waveform_row(1, 1, 1); // 70 ns
        waveform_row(0, 1, 0); // 75 ns
        waveform_row(0, 1, 0); // 80 ns
        waveform_row(0, 1, 0); // 85 ns
        waveform_row(1, 0, 0); // 90 ns
        // Independent top-level truth table, including back-to-back changes.
        truth_row(0, 0, 1);
        truth_row(0, 1, 0);
        truth_row(1, 0, 1);
        truth_row(1, 1, 1);
        truth_row(0, 1, 0);
        truth_row(0, 0, 1);
        $display("PASS: %0d waveform and truth-table checks", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
