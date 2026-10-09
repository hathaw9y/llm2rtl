module TopModule (
    input  logic [99:0] in,
    output wire  [99:0] out
);
    genvar bit_index;
    generate
        for (bit_index = 0; bit_index < 100; bit_index = bit_index + 1) begin : reverse_bits
            assign out[bit_index] = in[99-bit_index];
        end
    endgenerate
endmodule
