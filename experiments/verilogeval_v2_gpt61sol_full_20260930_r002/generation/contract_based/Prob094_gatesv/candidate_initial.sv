module TopModule (
    input  logic [3:0] in,
    output logic [3:0] out_both,
    output logic [3:0] out_any,
    output logic [3:0] out_different
);
    assign out_both = {1'b0, (in[2:0] & in[3:1])};
    assign out_any = {(in[3:1] | in[2:0]), 1'b0};
    assign out_different = in ^ {in[0], in[3:1]};
endmodule
