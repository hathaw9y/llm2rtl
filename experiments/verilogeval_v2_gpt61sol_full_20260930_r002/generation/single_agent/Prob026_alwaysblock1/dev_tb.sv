`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire out_assign, out_alwaysblock;
    logic values [0:3];
    logic expected;
    integer i, j;

    TopModule dut (.a(a), .b(b), .out_assign(out_assign),
                   .out_alwaysblock(out_alwaysblock));

    // Independent four-state AND truth table: zero dominates; only
    // two known ones yield one; every other pair yields unknown.
    task automatic check_pair(input logic av, input logic bv);
        begin
            a = av;
            b = bv;
            if ((av === 1'b0) || (bv === 1'b0))
                expected = 1'b0;
            else if ((av === 1'b1) && (bv === 1'b1))
                expected = 1'b1;
            else
                expected = 1'bx;
            #1;
            if ((out_assign !== expected) ||
                (out_alwaysblock !== expected))
                $fatal(1, "a=%b b=%b expected=%b assign=%b always=%b",
                       a, b, expected, out_assign, out_alwaysblock);
        end
    endtask

    initial begin
        values[0] = 1'b0;
        values[1] = 1'b1;
        values[2] = 1'bx;
        values[3] = 1'bz;
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1)
                check_pair(values[i], values[j]);
        // Reverse traversal exercises transitions on both inputs.
        for (i = 3; i >= 0; i = i - 1)
            for (j = 3; j >= 0; j = j - 1)
                check_pair(values[i], values[j]);
        $display("PASS: all AND input pairs and transitions checked");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
