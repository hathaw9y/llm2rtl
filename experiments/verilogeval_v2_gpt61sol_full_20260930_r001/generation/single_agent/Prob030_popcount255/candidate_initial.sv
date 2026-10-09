module TopModule (
    input  logic [254:0] in,
    output logic [7:0] out
);
    integer bit_index;
    always_comb begin
        out = 8'd0;
        for (bit_index = 0; bit_index < 255; bit_index = bit_index + 1) begin
            out = out + {7'b0, in[bit_index]};
        end
    end
endmodule
