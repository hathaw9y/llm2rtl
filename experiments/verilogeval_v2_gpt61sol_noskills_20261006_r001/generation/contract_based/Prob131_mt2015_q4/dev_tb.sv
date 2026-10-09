`timescale 1ns/1ps
module dev_tb;
    reg x, y;
    wire z;
    integer checks = 0;
    TopModule dut (.x(x), .y(y), .z(z));

    // Expected top output is a literal truth table independently derived
    // from the original A function, the B waveform, and OR/AND/XOR gates.
    task check_row(input reg row_x, input reg row_y, input reg expected);
        begin
            x = row_x;
            y = row_y;
            #0; // sample after combinational delta settling, at the same time
            if (z !== expected)
                $fatal(1, "Mismatch at %0t x=%b y=%b z=%b expected=%b", $time, x, y, z, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_row(0, 0, 1);        // 0 ns
        #5 check_row(0, 0, 1);     // 5 ns
        #5 check_row(0, 0, 1);     // 10 ns
        #5 check_row(0, 0, 1);     // 15 ns
        #5 check_row(0, 0, 1);     // 20 ns
        #5 check_row(1, 0, 1);     // 25 ns: A=1 B=0
        #5 check_row(1, 0, 1);     // 30 ns
        #5 check_row(0, 1, 0);     // 35 ns
        #5 check_row(0, 1, 0);     // 40 ns
        #5 check_row(1, 1, 1);     // 45 ns
        #5 check_row(1, 1, 1);     // 50 ns
        #5 check_row(0, 0, 1);     // 55 ns
        #5 check_row(0, 1, 0);     // 60 ns
        #5 check_row(0, 1, 0);     // 65 ns
        #5 check_row(1, 1, 1);     // 70 ns
        #5 check_row(0, 1, 0);     // 75 ns
        #5 check_row(0, 1, 0);     // 80 ns
        #5 check_row(0, 1, 0);     // 85 ns
        #5 check_row(1, 0, 1);     // 90 ns
        if (checks != 19) $fatal(1, "Incorrect check count");
        $display("PASS: all 19 original waveform rows, covering all binary inputs");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Bounded timeout");
    end
endmodule
