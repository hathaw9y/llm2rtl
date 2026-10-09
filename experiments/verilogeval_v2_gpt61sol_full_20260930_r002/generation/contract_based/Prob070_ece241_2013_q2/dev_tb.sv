`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire out_sop, out_pos;
    integer checked;
    integer value;
    TopModule dut (.a(a), .b(b), .c(c), .d(d),
                   .out_sop(out_sop), .out_pos(out_pos));

    task automatic check_pattern(input integer pattern);
        logic expected;
        logic specified;
        begin
            {a,b,c,d} = pattern[3:0];
            // Literal original truth table, independent of DUT expressions.
            specified = 1'b1;
            expected = 1'b0;
            case (pattern)
                2, 7, 15: expected = 1'b1;
                0, 1, 4, 5, 6, 9, 10, 13, 14: expected = 1'b0;
                3, 8, 11, 12: specified = 1'b0;
                default: $fatal(1, "Invalid test pattern %0d", pattern);
            endcase
            #1;
            if (specified) begin
                if (out_sop !== expected || out_pos !== expected)
                    $fatal(1, "pattern=%0d expected=%b sop=%b pos=%b",
                           pattern, expected, out_sop, out_pos);
                checked = checked + 1;
            end
        end
    endtask

    initial begin
        checked = 0;
        for (value = 0; value < 16; value = value + 1)
            check_pattern(value);
        for (value = 15; value >= 0; value = value - 1)
            check_pattern(value);
        if (checked != 24) $fatal(1, "Coverage count %0d", checked);
        $display("PASS: all 12 specified patterns checked in both sweep directions");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
