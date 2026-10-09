`timescale 1ns/1ps
module dev_tb;
    reg a, b;
    wire out_assign, out_alwaysblock;
    integer i, j;
    reg expected;
    TopModule dut (.a(a), .b(b), .out_assign(out_assign),
                   .out_alwaysblock(out_alwaysblock));

    function automatic reg value(input integer index);
        case (index)
            0: value = 1'b0;
            1: value = 1'b1;
            2: value = 1'bx;
            3: value = 1'bz;
        endcase
    endfunction

    initial begin
        // Independent truth-table oracle: zero dominates; only two ones
        // yield one; all other four-state combinations yield unknown.
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                a = value(i);
                b = value(j);
                if (i == 0 || j == 0) expected = 1'b0;
                else if (i == 1 && j == 1) expected = 1'b1;
                else expected = 1'bx;
                #1;
                if (out_assign !== expected || out_alwaysblock !== expected)
                    $fatal(1, "AND mismatch a=%b b=%b expected=%b assign=%b always=%b",
                           a, b, expected, out_assign, out_alwaysblock);
            end
        end
        $display("PASS all 16 four-state AND input combinations");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
