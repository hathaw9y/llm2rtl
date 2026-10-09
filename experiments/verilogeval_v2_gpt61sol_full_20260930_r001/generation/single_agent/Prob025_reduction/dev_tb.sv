`timescale 1ns/1ps
module dev_tb;
    logic [7:0] in;
    logic parity;
    integer value;
    integer bit_index;
    integer ones;
    logic expected;

    TopModule dut (.in(in), .parity(parity));

    initial begin
        for (value = 0; value < 256; value = value + 1) begin
            in = value[7:0];
            ones = 0;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                if (in[bit_index]) ones = ones + 1;
            expected = (ones % 2) == 1;
            #1;
            if (parity !== expected)
                $fatal(1, "FAIL: in=%h expected=%b actual=%b", in, expected, parity);
        end
        $display("PASS: all 256 byte values produce even parity");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "FAIL: development timeout");
    end
endmodule
