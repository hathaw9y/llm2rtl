module dev_tb;
    logic a, b, c, d;
    logic out;
    logic expected;
    integer i;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            {a,b,c,d} = i[3:0];
            // Direct transcription of the map, indexed by cd then ab.
            case ({c,d})
                2'b00: expected = ({a,b} != 2'b11);
                2'b01: expected = (b == 1'b0);
                2'b11: expected = ({a,b} != 2'b00);
                2'b10: expected = (a == 1'b0);
            endcase
            #1;
            if (out !== expected)
                $fatal(1, "FAIL abcd=%b expected=%b actual=%b", {a,b,c,d}, expected, out);
        end
        $display("PASS: all 16 binary input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
