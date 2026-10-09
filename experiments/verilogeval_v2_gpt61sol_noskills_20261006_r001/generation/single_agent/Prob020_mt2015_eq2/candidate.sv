module TopModule (
    input wire [1:0] A,
    input wire [1:0] B,
    output wire z
);
    assign z = (A == B);
endmodule
