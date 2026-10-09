module TopModule (
    input  logic [3:0] x,
    output logic       f
);
    // Rows are {x[2], x[3]}; columns are {x[0], x[1]}.
    assign f = (~x[2] & ~x[3] & ~x[1])
             | (x[2] & x[3] & (~x[0] | x[1]))
             | (x[2] & ~x[3] & (~x[0] | ~x[1]));
endmodule
