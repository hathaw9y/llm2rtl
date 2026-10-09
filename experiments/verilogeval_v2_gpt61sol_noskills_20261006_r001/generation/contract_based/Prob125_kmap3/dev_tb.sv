`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire out;
    reg expected;
    integer i;
    integer checked;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));

    initial begin
        checked = 0;
        for (i = 0; i < 16; i = i + 1) begin
            {a,b,c,d} = i[3:0];
            // Original map, explicitly enumerated in abcd binary order.
            case (i)
                0, 1, 5, 6, 7: expected = 1'b0;
                2, 3, 8, 10, 11, 12, 14, 15: expected = 1'b1;
                4, 9, 13: expected = 1'bx; // Original don't-care cells.
                default: $fatal(1, "Unexpected stimulus index");
            endcase
            #1;
            if (expected !== 1'bx) begin
                if (out !== expected)
                    $fatal(1, "abcd=%b expected=%b got=%b", {a,b,c,d}, expected, out);
                checked = checked + 1;
            end
        end
        if (checked != 13) $fatal(1, "Incomplete map coverage");
        $display("PASS: all 13 constrained cells checked; all 16 combinations exercised");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
