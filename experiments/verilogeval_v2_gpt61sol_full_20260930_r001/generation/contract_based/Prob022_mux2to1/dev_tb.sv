module dev_tb;
    logic a, b, sel;
    logic out;
    logic expected;
    integer i;
    TopModule dut (.a(a), .b(b), .sel(sel), .out(out));
    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            {a, b, sel} = i[2:0];
            if (sel == 1'b0) expected = a;
            else expected = b;
            #1;
            if (out !== expected)
                $fatal(1, "FAIL a=%b b=%b sel=%b out=%b expected=%b", a, b, sel, out, expected);
        end
        $display("PASS: all 8 binary mux combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
