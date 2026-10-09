module dev_tb;
    logic a, b, c, d;
    wire out;
    logic expected;
    integer checked;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));
    initial begin
        checked = 0;
        for (integer i = 0; i < 16; i = i + 1) begin
            {a,b,c,d} = i[3:0];
            // Truth table transcribed from the specified Karnaugh map.
            case (i)
                0, 1, 5, 6, 7: expected = 1'b0;
                2, 3, 8, 10, 11, 12, 14, 15: expected = 1'b1;
                default: expected = 1'bx; // Don't-care cells: 4, 9, 13.
            endcase
            #1;
            if (expected !== 1'bx) begin
                checked = checked + 1;
                if (out !== expected)
                    $fatal(1, "FAIL input=%b expected=%b actual=%b", {a,b,c,d}, expected, out);
            end
        end
        $display("PASS: all %0d specified cells checked; all 16 inputs exercised", checked);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
