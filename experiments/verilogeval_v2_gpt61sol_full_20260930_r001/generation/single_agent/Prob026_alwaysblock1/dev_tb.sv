module dev_tb;
    logic a, b;
    wire out_assign, out_alwaysblock;
    logic expected;
    logic [3:0] values;
    integer i, j;
    TopModule dut (.a(a), .b(b), .out_assign(out_assign),
                   .out_alwaysblock(out_alwaysblock));
    initial begin
        values = {1'bz, 1'bx, 1'b1, 1'b0};
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                a = values[i];
                b = values[j];
                expected = a & b;
                #1;
                if (out_assign !== expected || out_alwaysblock !== expected)
                    $fatal(1, "FAIL a=%b b=%b assign=%b always=%b expected=%b",
                           a, b, out_assign, out_alwaysblock, expected);
            end
        end
        $display("PASS: all 16 four-state input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
