module TopModule (
    input  wire [2:0] in,
    output wire [1:0] out
);
    assign out = {1'b0, in[0]} + {1'b0, in[1]} + {1'b0, in[2]};
endmodule
