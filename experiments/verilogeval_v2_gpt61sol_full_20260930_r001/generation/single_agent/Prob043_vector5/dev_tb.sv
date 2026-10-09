module dev_tb;
    logic a, b, c, d, e;
    wire [24:0] out;
    logic [4:0] bits_in;
    logic expected;
    integer pattern, row, col;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .e(e), .out(out));
    initial begin
        for (pattern = 0; pattern < 32; pattern = pattern + 1) begin
            bits_in = 5'(pattern);
            {a, b, c, d, e} = bits_in;
            #1;
            for (row = 0; row < 5; row = row + 1) begin
                for (col = 0; col < 5; col = col + 1) begin
                    expected = (bits_in[4-row] == bits_in[4-col]);
                    if (out[24-row*5-col] !== expected)
                        $fatal(1, "FAIL pattern=%0d row=%0d col=%0d", pattern, row, col);
                end
            end
        end
        $display("PASS: 32 input combinations, 800 pairwise comparisons");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
