`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire out_assign, out_alwaysblock;
    integer checks = 0;
    logic states [0:3];
    TopModule dut (.a(a), .b(b), .out_assign(out_assign), .out_alwaysblock(out_alwaysblock));

    task automatic check(input logic av, input logic bv, input logic expected);
        a = av;
        b = bv;
        #1;
        if (out_assign !== expected || out_alwaysblock !== expected)
            $fatal(1, "FAIL a=%b b=%b expected=%b assign=%b always=%b", a, b, expected, out_assign, out_alwaysblock);
        checks = checks + 1;
    endtask

    initial begin
        states[0] = 1'b0;
        states[1] = 1'b1;
        states[2] = 1'bx;
        states[3] = 1'bz;
        // All binary pairs, followed by every ordered binary transition.
        for (integer src = 0; src < 4; src = src + 1) begin
            check(src[1], src[0], (src == 3) ? 1'b1 : 1'b0);
            for (integer dst = 0; dst < 4; dst = dst + 1) begin
                check(src[1], src[0], (src == 3) ? 1'b1 : 1'b0);
                check(dst[1], dst[0], (dst == 3) ? 1'b1 : 1'b0);
            end
        end
        // Independent four-state truth table: zero dominates; only 1/1 is one.
        for (integer i = 0; i < 4; i = i + 1)
            for (integer j = 0; j < 4; j = j + 1) begin
                if (i == 0 || j == 0) check(states[i], states[j], 1'b0);
                else if (i == 1 && j == 1) check(states[i], states[j], 1'b1);
                else check(states[i], states[j], 1'bx);
            end
        $display("PASS: %0d AND checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
