module TopModule (
    input wire [4:1] x,
    output wire f
);
    assign f = (x[3] & ~x[1]) |
               (x[1] & x[2] & ~x[3] & x[4]);
endmodule
