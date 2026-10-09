`timescale 1ns/1ps
module dev_tb;
    reg [7:0] in;
    wire parity;
    integer value;
    integer bit_index;
    integer ones;
    reg expected;

    TopModule dut (.in(in), .parity(parity));

    initial begin
        for (value = 0; value < 256; value = value + 1) begin
            in = value;
            ones = 0;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                if ((value & (1 << bit_index)) != 0)
                    ones = ones + 1;
            expected = (ones % 2) == 1;
            #1;
            if (parity !== expected)
                $fatal(1, "Parity mismatch: in=%h expected=%b got=%b", in, expected, parity);
        end
        in = 8'b0000000x;
        #1;
        if (parity !== 1'bx) $fatal(1, "X input must produce unknown parity");
        in = 8'b1111111z;
        #1;
        if (parity !== 1'bx) $fatal(1, "Z input must produce unknown parity");
        in = 8'h00;
        #1;
        if (parity !== 1'b0) $fatal(1, "Parity did not recover after unknown input");
        $display("PASS: all 256 bytes and four-state propagation checks");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
