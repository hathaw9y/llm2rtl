module dev_tb;
    logic a, b, sel;
    wire out;
    logic expected;
    integer i;
    TopModule dut (.a(a), .b(b), .sel(sel), .out(out));
    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            {sel, b, a} = i[2:0];
            expected = ((sel == 1'b0) && a) || ((sel == 1'b1) && b);
            #1;
            if (out !== expected)
                $fatal(1, "FAIL a=%b b=%b sel=%b out=%b expected=%b", a, b, sel, out, expected);
        end
        $display("PASS: all 8 binary input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
