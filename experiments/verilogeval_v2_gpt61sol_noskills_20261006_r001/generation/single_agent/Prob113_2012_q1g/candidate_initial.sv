module TopModule (
    input wire [3:0] x,
    output wire f
);
    assign f = (~x[2] & ~x[3] & ~x[1]) |
               ( x[2] &  x[3] & (~x[0] | x[1])) |
               ( x[2] & ~x[3] & (~x[0] | ~x[1]));
endmodule
