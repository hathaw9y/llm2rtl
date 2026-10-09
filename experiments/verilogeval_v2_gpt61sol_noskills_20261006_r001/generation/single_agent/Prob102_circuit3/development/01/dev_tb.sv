`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire q;
    integer checks = 0;
    TopModule dut(.a(a), .b(b), .c(c), .d(d), .q(q));

    // Each row starts at its original timestamp; sample after delta settling.
    task row(input integer timestamp, input [3:0] inputs, input expected);
        begin
            if ($time != timestamp)
                $fatal(1, "Stimulus timing error: expected %0d ns, got %0t", timestamp, $time);
            {a,b,c,d} = inputs;
            #0;
            if (q !== expected)
                $fatal(1, "At %0t inputs=%b: q=%b expected=%b", $time, inputs, q, expected);
            checks = checks + 1;
            #5;
        end
    endtask

    initial begin
        row( 0, 4'b0000, 1'b0);
        row( 5, 4'b0000, 1'b0);
        row(10, 4'b0000, 1'b0);
        row(15, 4'b0000, 1'b0);
        row(20, 4'b0001, 1'b0);
        row(25, 4'b0010, 1'b0);
        row(30, 4'b0011, 1'b0);
        row(35, 4'b0100, 1'b0);
        row(40, 4'b0101, 1'b1);
        row(45, 4'b0110, 1'b1);
        row(50, 4'b0111, 1'b1);
        row(55, 4'b1000, 1'b0);
        row(60, 4'b1001, 1'b1);
        row(65, 4'b1010, 1'b1);
        row(70, 4'b1011, 1'b1);
        row(75, 4'b1100, 1'b0);
        row(80, 4'b1101, 1'b1);
        row(85, 4'b1110, 1'b1);
        row(90, 4'b1111, 1'b1);
        if (checks != 19) $fatal(1, "Incomplete waveform replay");
        $display("PASS: all 19 waveform rows, including all 16 input combinations");
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
