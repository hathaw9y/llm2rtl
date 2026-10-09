module dev_tb;
    logic [7:0] in;
    wire [7:0] out;
    integer value, bit_index, remaining, reversed;
    logic [7:0] expected;
    TopModule dut (.in(in), .out(out));

    initial begin
        for (value = 0; value < 256; value = value + 1) begin
            remaining = value;
            reversed = 0;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                reversed = reversed * 2 + remaining % 2;
                remaining = remaining / 2;
            end
            in = value[7:0];
            expected = reversed[7:0];
            #1;
            if (out !== expected)
                $fatal(1, "FAIL in=%h out=%h expected=%h", in, out, expected);
        end
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            in = 8'b0;
            expected = 8'b0;
            in[bit_index] = 1'bx;
            expected[7-bit_index] = 1'bx;
            #1;
            if (out !== expected) $fatal(1, "FAIL X bit %0d", bit_index);
            in[bit_index] = 1'bz;
            expected[7-bit_index] = 1'bz;
            #1;
            if (out !== expected) $fatal(1, "FAIL Z bit %0d", bit_index);
        end
        $display("PASS: 256 binary cases and 16 X/Z cases");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL watchdog timeout");
    end
endmodule
