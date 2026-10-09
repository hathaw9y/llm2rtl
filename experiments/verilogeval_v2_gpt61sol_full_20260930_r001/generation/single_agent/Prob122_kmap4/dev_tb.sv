module dev_tb;
    logic a, b, c, d;
    wire out;
    logic expected;
    integer i;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            {a,b,c,d} = i[3:0];
            // Literal cell values, indexed by binary {a,b,c,d}.
            case ({a,b,c,d})
                4'b0000: expected = 0;
                4'b0001: expected = 1;
                4'b0010: expected = 1;
                4'b0011: expected = 0;
                4'b0100: expected = 1;
                4'b0101: expected = 0;
                4'b0110: expected = 0;
                4'b0111: expected = 1;
                4'b1000: expected = 1;
                4'b1001: expected = 0;
                4'b1010: expected = 0;
                4'b1011: expected = 1;
                4'b1100: expected = 0;
                4'b1101: expected = 1;
                4'b1110: expected = 1;
                4'b1111: expected = 0;
                default: expected = 1'bx;
            endcase
            #1;
            if (out !== expected)
                $fatal(1, "FAIL inputs=%b expected=%b actual=%b", {a,b,c,d}, expected, out);
        end
        $display("PASS: all 16 Karnaugh-map cells checked");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
