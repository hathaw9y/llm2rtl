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
            expected = (ones % 2);
            #1;
            if (parity !== expected)
                $fatal(1, "Byte %0d: expected parity %b, got %b", value, expected, parity);
        end
        // Supplemental checks of standard four-state XOR behavior.
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            in = 8'b0;
            in[bit_index] = 1'bx;
            #1;
            if (parity !== 1'bx)
                $fatal(1, "X input at bit %0d did not propagate", bit_index);
            in = 8'hff;
            in[bit_index] = 1'bz;
            #1;
            if (parity !== 1'bx)
                $fatal(1, "Z input at bit %0d did not propagate", bit_index);
        end
        in = 8'h01;
        #1;
        if (parity !== 1'b1)
            $fatal(1, "Known input did not restore known parity");
        $display("PASS: all 256 bytes and supplemental four-state checks");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
