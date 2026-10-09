`timescale 1ns/1ps
module dev_tb;
    reg [7:0] in;
    wire [31:0] out;
    reg signed [31:0] expected;
    integer value;
    integer bit_index;
    TopModule dut (.in(in), .out(out));

    initial begin
        for (value = 0; value < 256; value = value + 1) begin
            in = value;
            if (value < 128)
                expected = value;
            else
                expected = value - 256;
            #1;
            if (out !== expected)
                $fatal(1, "in=%h expected=%h observed=%h", in, expected, out);
        end
        in = 8'bx0101010;
        #1;
        if (out[7:0] !== in) $fatal(1, "Low bits changed with unknown sign");
        for (bit_index = 8; bit_index < 32; bit_index = bit_index + 1)
            if (out[bit_index] !== 1'bx) $fatal(1, "Unknown sign not propagated");
        in = 8'bz1010101;
        #1;
        if (out[7:0] !== in) $fatal(1, "Low bits changed with high impedance sign");
        for (bit_index = 8; bit_index < 32; bit_index = bit_index + 1)
            if (out[bit_index] !== 1'bz) $fatal(1, "High impedance sign not propagated");
        in = 8'b01xz01xz;
        #1;
        if (out !== 32'b00000000000000000000000001xz01xz)
            $fatal(1, "Unknown low bits not preserved");
        $display("PASS: exhaustive sign extension and four-state propagation checks");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
