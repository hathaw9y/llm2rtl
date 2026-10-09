`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire q;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));

    task check_row(input [3:0] inputs, input expected);
        begin
            {a,b,c,d} = inputs;
            #0; // Settle combinational logic without moving the waveform timestamp.
            if (q !== expected)
                $fatal(1, "Mismatch at %0t: abcd=%b expected=%b actual=%b",
                       $time, inputs, expected, q);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_row(4'b0000, 1'b1);      // 0 ns
        #5 check_row(4'b0000, 1'b1);   // 5 ns
        #5 check_row(4'b0000, 1'b1);   // 10 ns
        #5 check_row(4'b0000, 1'b1);   // 15 ns
        #5 check_row(4'b0001, 1'b0);   // 20 ns
        #5 check_row(4'b0010, 1'b0);   // 25 ns
        #5 check_row(4'b0011, 1'b1);   // 30 ns
        #5 check_row(4'b0100, 1'b0);   // 35 ns
        #5 check_row(4'b0101, 1'b1);   // 40 ns
        #5 check_row(4'b0110, 1'b1);   // 45 ns
        #5 check_row(4'b0111, 1'b0);   // 50 ns
        #5 check_row(4'b1000, 1'b0);   // 55 ns
        #5 check_row(4'b1001, 1'b1);   // 60 ns
        #5 check_row(4'b1010, 1'b1);   // 65 ns
        #5 check_row(4'b1011, 1'b0);   // 70 ns
        #5 check_row(4'b1100, 1'b1);   // 75 ns
        #5 check_row(4'b1101, 1'b0);   // 80 ns
        #5 check_row(4'b1110, 1'b0);   // 85 ns
        #5 check_row(4'b1111, 1'b1);   // 90 ns
        if (checks != 19) $fatal(1, "Incomplete waveform replay");
        $display("PASS: all 19 original waveform rows checked");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
