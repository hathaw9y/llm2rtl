`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire q;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));

    // Expected values are transcribed directly from the original table.
    // #0 permits combinational settling without shifting physical timestamps.
    task check_row(input [3:0] stimulus, input expected);
        begin
            {a,b,c,d} = stimulus;
            #0;
            if (q !== expected)
                $fatal(1, "At %0t: abcd=%b expected q=%b, got %b",
                       $time, stimulus, expected, q);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_row(4'b0000, 1'b0);       // 0ns
        #5; check_row(4'b0000, 1'b0);   // 5ns
        #5; check_row(4'b0000, 1'b0);   // 10ns
        #5; check_row(4'b0000, 1'b0);   // 15ns
        #5; check_row(4'b0001, 1'b0);   // 20ns
        #5; check_row(4'b0010, 1'b1);   // 25ns
        #5; check_row(4'b0011, 1'b1);   // 30ns
        #5; check_row(4'b0100, 1'b1);   // 35ns
        #5; check_row(4'b0101, 1'b1);   // 40ns
        #5; check_row(4'b0110, 1'b1);   // 45ns
        #5; check_row(4'b0111, 1'b1);   // 50ns
        #5; check_row(4'b1000, 1'b0);   // 55ns
        #5; check_row(4'b1001, 1'b0);   // 60ns
        #5; check_row(4'b1010, 1'b1);   // 65ns
        #5; check_row(4'b1011, 1'b1);   // 70ns
        #5; check_row(4'b1100, 1'b1);   // 75ns
        #5; check_row(4'b1101, 1'b1);   // 80ns
        #5; check_row(4'b1110, 1'b1);   // 85ns
        #5; check_row(4'b1111, 1'b1);   // 90ns
        if (checks != 19) $fatal(1, "Incomplete waveform replay");
        $display("PASS: 19 original waveform rows, all 16 binary combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
