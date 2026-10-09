module TopModule (
    input  logic [3:0] x,
    input  logic [3:0] y,
    output logic [4:0] sum
);
    logic [4:0] carry;
    assign carry[0] = 1'b0;

    generate
        for (genvar bit_index = 0; bit_index < 4; bit_index = bit_index + 1) begin : full_adders
            assign sum[bit_index] = x[bit_index] ^ y[bit_index] ^ carry[bit_index];
            assign carry[bit_index+1] = (x[bit_index] & y[bit_index]) |
                                        (x[bit_index] & carry[bit_index]) |
                                        (y[bit_index] & carry[bit_index]);
        end
    endgenerate

    assign sum[4] = carry[4];
endmodule
