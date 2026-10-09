module TopModule (
    input  logic [3:0] x,
    input  logic [3:0] y,
    output logic [4:0] sum
);
    logic [4:0] carry;
    assign carry[0] = 1'b0;

    for (genvar bit_idx = 0; bit_idx < 4; bit_idx++) begin : full_adders
        assign sum[bit_idx] = x[bit_idx] ^ y[bit_idx] ^ carry[bit_idx];
        assign carry[bit_idx+1] = (x[bit_idx] & y[bit_idx]) |
                                  (x[bit_idx] & carry[bit_idx]) |
                                  (y[bit_idx] & carry[bit_idx]);
    end
    assign sum[4] = carry[4];
endmodule
