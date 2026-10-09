module dev_tb;
    logic a, b, c, d;
    wire out_sop, out_pos;
    logic expected;
    integer checked = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d),
                   .out_sop(out_sop), .out_pos(out_pos));
    task automatic check_input(input integer value);
        begin
            {a,b,c,d} = value[3:0];
            #1;
            case (value)
                2,7,15: expected = 1'b1;
                0,1,4,5,6,9,10,13,14: expected = 1'b0;
                default: expected = 1'bx;
            endcase
            if (expected !== 1'bx) begin
                checked = checked + 1;
                if (out_sop !== expected || out_pos !== expected)
                    $fatal(1, "FAIL input=%0d expected=%b sop=%b pos=%b",
                           value, expected, out_sop, out_pos);
            end
        end
    endtask
    initial begin
        for (integer i = 0; i < 16; i = i + 1) check_input(i);
        for (integer i = 15; i >= 0; i = i - 1) check_input(i);
        $display("PASS: %0d specified-input checks across two exhaustive sweeps", checked);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
