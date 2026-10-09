`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire q;
    // Bit index is the original binary input tuple abcd.
    // Expected values copied from the original waveform, not calculated by XOR.
    localparam logic [15:0] ORIGINAL_Q = 16'b1001011001101001;
    integer checks = 0;
    integer row;
    integer value;

    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));

    task automatic check_q(input logic expected);
        begin
            if (q !== expected)
                $fatal(1, "Mismatch at %0t: abcd=%b%b%b%b expected=%b actual=%b",
                       $time, a, b, c, d, expected, q);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Replay every original timestamp. #0 allows continuous assignment
        // settling without moving the sample to another timestamp.
        for (row = 0; row < 19; row = row + 1) begin
            if (row != 0) #5;
            if (row < 4) value = 0;
            else value = row - 3;
            {a,b,c,d} = value[3:0];
            #0;
            check_q(ORIGINAL_Q[value]);
        end
        // Exercise the same literal oracle in reverse order, including the
        // all-one/all-zero boundaries and repeated input combinations.
        for (value = 15; value >= 0; value = value - 1) begin
            #5;
            {a,b,c,d} = value[3:0];
            #0;
            check_q(ORIGINAL_Q[value]);
        end
        $display("PASS: %0d waveform and reverse-order checks", checks);
        $finish;
    end

    initial begin
        #250;
        $fatal(1, "Timeout");
    end
endmodule
