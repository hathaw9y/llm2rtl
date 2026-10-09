`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire q;
    integer checks = 0;
    integer idx;
    // Literal truth table from original rows, indexed by {a,b,c,d}.
    localparam logic [15:0] EXPECTED = 16'b1110_1110_1110_0000;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));

    task automatic waveform_row(input logic [3:0] inputs,
                                input logic expected_q);
        begin
            {a,b,c,d} = inputs;
            #0.001;
            if (q !== expected_q)
                $fatal(1, "Mismatch at %0t: abcd=%b expected=%b actual=%b",
                       $time, inputs, expected_q, q);
            checks = checks + 1;
            #4.999;
        end
    endtask

    initial begin
        waveform_row(4'b0000, 1'b0); // 0 ns
        waveform_row(4'b0000, 1'b0); // 5 ns
        waveform_row(4'b0000, 1'b0); // 10 ns
        waveform_row(4'b0000, 1'b0); // 15 ns
        waveform_row(4'b0001, 1'b0); // 20 ns
        waveform_row(4'b0010, 1'b0); // 25 ns
        waveform_row(4'b0011, 1'b0); // 30 ns
        waveform_row(4'b0100, 1'b0); // 35 ns
        waveform_row(4'b0101, 1'b1); // 40 ns
        waveform_row(4'b0110, 1'b1); // 45 ns
        waveform_row(4'b0111, 1'b1); // 50 ns
        waveform_row(4'b1000, 1'b0); // 55 ns
        waveform_row(4'b1001, 1'b1); // 60 ns
        waveform_row(4'b1010, 1'b1); // 65 ns
        waveform_row(4'b1011, 1'b1); // 70 ns
        waveform_row(4'b1100, 1'b0); // 75 ns
        waveform_row(4'b1101, 1'b1); // 80 ns
        waveform_row(4'b1110, 1'b1); // 85 ns
        waveform_row(4'b1111, 1'b1); // 90 ns
        for (idx = 15; idx >= 0; idx = idx - 1)
            waveform_row(idx[3:0], EXPECTED[idx]);
        $display("PASS: %0d original-waveform and reverse-order checks", checks);
        $finish;
    end

    initial begin
        #250;
        $fatal(1, "Timeout");
    end
endmodule
