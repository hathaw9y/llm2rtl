module dev_tb;
    logic [7:0] in;
    logic [7:0] out;
    logic [7:0] expected;
    integer value;
    integer bit_index;
    TopModule dut (.in(in), .out(out));
    initial begin
        for (value = 0; value < 256; value = value + 1) begin
            in = value[7:0];
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                expected[bit_index] = in[7-bit_index];
            #1;
            if (out !== expected)
                $fatal(1, "FAIL input=%h expected=%h actual=%h", in, expected, out);
        end
        $display("PASS: all 256 input values");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: timeout");
    end
endmodule
