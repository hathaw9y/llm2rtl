module dev_tb;
    logic [7:0] in;
    logic [2:0] pos;
    integer value;
    integer bit_index;
    integer expected;
    bit found;
    TopModule dut (.in(in), .pos(pos));
    initial begin
        for (value = 0; value < 256; value = value + 1) begin
            in = value[7:0];
            expected = 0;
            found = 0;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (in[bit_index] && !found) begin
                    expected = bit_index;
                    found = 1;
                end
            end
            #1;
            if (pos !== expected[2:0])
                $fatal(1, "FAIL in=%b pos=%d expected=%d", in, pos, expected);
        end
        $display("PASS: all 256 binary inputs");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: development timeout");
    end
endmodule
