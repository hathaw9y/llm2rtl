module dev_tb;
    logic sel;
    logic [7:0] a, b;
    wire [7:0] out;
    integer av, bv, sv, bit_index;
    integer checks = 0;
    logic expected_bit;
    TopModule dut (.sel(sel), .a(a), .b(b), .out(out));

    initial begin
        for (av = 0; av < 256; av = av + 1)
            for (bv = 0; bv < 256; bv = bv + 1)
                for (sv = 0; sv < 2; sv = sv + 1) begin
                    a = av;
                    b = bv;
                    sel = sv;
                    #1;
                    for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                        if (sv == 0) expected_bit = a[bit_index];
                        else expected_bit = b[bit_index];
                        if (out[bit_index] !== expected_bit)
                            $fatal(1, "Mismatch a=%h b=%h sel=%b bit=%0d out=%h", a, b, sel, bit_index, out);
                    end
                    checks = checks + 1;
                end
        a = 8'ha5; b = 8'ha5; sel = 1'bx; #1;
        if (out !== 8'ha5) $fatal(1, "X select equal-data mismatch");
        sel = 1'bz; #1;
        if (out !== 8'ha5) $fatal(1, "Z select equal-data mismatch");
        a = 8'ha5; b = 8'ha7; sel = 1'bx; #1;
        if (out !== 8'b101001x1) $fatal(1, "X select merge mismatch");
        sel = 1'bz; #1;
        if (out !== 8'b101001x1) $fatal(1, "Z select merge mismatch");
        $display("PASS: %0d exhaustive binary input cases and 4 X/Z cases", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Testbench timeout");
    end
endmodule
