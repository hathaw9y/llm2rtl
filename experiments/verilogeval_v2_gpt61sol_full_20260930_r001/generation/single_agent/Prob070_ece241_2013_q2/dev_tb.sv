module dev_tb;
    logic a, b, c, d;
    wire out_sop, out_pos;
    integer i;
    integer checked;
    logic expected;
    TopModule dut (.a(a), .b(b), .c(c), .d(d),
                   .out_sop(out_sop), .out_pos(out_pos));
    initial begin
        checked = 0;
        for (i = 0; i < 16; i = i + 1) begin
            {a,b,c,d} = i[3:0];
            #1;
            case (i)
                2, 7, 15: expected = 1'b1;
                0, 1, 4, 5, 6, 9, 10, 13, 14: expected = 1'b0;
                default: expected = 1'bx;
            endcase
            if (expected !== 1'bx) begin
                checked = checked + 1;
                if (out_sop !== expected || out_pos !== expected)
                    $fatal(1, "FAIL input=%0d expected=%b sop=%b pos=%b",
                           i, expected, out_sop, out_pos);
            end
            if (out_sop !== out_pos)
                $fatal(1, "FAIL expressions disagree at input=%0d", i);
        end
        $display("PASS: all 12 specified inputs checked; expressions agree on all 16 inputs");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL timeout");
    end
endmodule
