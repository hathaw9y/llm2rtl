`timescale 1ns/1ps
module dev_tb;
    reg x, y;
    wire z;
    integer checks = 0;
    TopModule dut (.x(x), .y(y), .z(z));

    task automatic row(input reg xv, input reg yv, input reg expected);
        begin
            x = xv;
            y = yv;
            #0.001;
            if (z !== expected)
                $fatal(1, "Mismatch at %0t: x=%b y=%b z=%b expected=%b", $time, x, y, z, expected);
            checks = checks + 1;
            #4.999;
        end
    endtask

    initial begin
        // Original waveform: drive every row at its exact 5ns boundary.
        row(0, 0, 1); // 0ns
        row(0, 0, 1); // 5ns
        row(0, 0, 1); // 10ns
        row(0, 0, 1); // 15ns
        row(0, 0, 1); // 20ns
        row(1, 0, 0); // 25ns
        row(1, 0, 0); // 30ns
        row(0, 1, 0); // 35ns
        row(0, 1, 0); // 40ns
        row(1, 1, 1); // 45ns
        row(1, 1, 1); // 50ns
        row(0, 0, 1); // 55ns
        row(0, 1, 0); // 60ns
        row(0, 1, 0); // 65ns
        row(1, 1, 1); // 70ns
        row(0, 1, 0); // 75ns
        row(0, 1, 0); // 80ns
        row(0, 1, 0); // 85ns
        row(1, 0, 0); // 90ns
        // Additional binary truth-table cases with single-input transitions.
        row(0, 0, 1);
        row(0, 1, 0);
        row(1, 1, 1);
        row(1, 0, 0);
        row(0, 0, 1);
        if (checks != 24) $fatal(1, "Missing checks");
        $display("PASS: original waveform and binary transition checks (%0d)", checks);
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
