module TopModule (
    input  logic [254:0] in,
    output logic [7:0]   out
);
    integer i;
    always_comb begin
        out = 8'd0;
        for (i = 0; i < 255; i = i + 1) begin
            out = out + {7'b0, in[i]};
        end
    end
endmodule
