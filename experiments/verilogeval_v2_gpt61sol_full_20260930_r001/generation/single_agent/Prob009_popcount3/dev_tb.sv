module dev_tb;
    logic [2:0] in;
    logic [1:0] out;
    integer value;
    integer bit_index;
    integer expected;
    TopModule dut (.in(in), .out(out));
    initial begin
        for (value = 0; value < 8; value = value + 1) begin
            in = value[2:0];
            expected = 0;
            for (bit_index = 0; bit_index < 3; bit_index = bit_index + 1)
                if (in[bit_index]) expected = expected + 1;
            #1;
            if (out !== expected[1:0])
                $fatal(1, "FAIL in=%b out=%d expected=%d", in, out, expected);
        end
        $display("PASS: all 8 input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
