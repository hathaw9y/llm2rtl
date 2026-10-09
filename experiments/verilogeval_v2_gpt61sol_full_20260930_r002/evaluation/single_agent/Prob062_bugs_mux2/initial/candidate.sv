module TopModule (
    input logic sel,
    input logic [7:0] a,
    input logic [7:0] b,
    output logic out
);
    assign out = sel ? b : a;
endmodule
