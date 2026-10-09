module dev_tb;
    logic a, b, c, d;
    wire out, out_n;
    logic expected;
    integer i;

    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out), .out_n(out_n));

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            {a, b, c, d} = i[3:0];
            expected = ((a == 1'b1) && (b == 1'b1)) ||
                       ((c == 1'b1) && (d == 1'b1));
            #1;
            if (out !== expected || out_n !== ~expected)
                $fatal(1, "FAIL inputs=%b out=%b out_n=%b expected=%b", {a,b,c,d}, out, out_n, expected);
        end
        $display("PASS: all 16 binary input combinations");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
