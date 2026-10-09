module TopModule (
    input  logic [255:0] in,
    input  logic [7:0]   sel,
    output wire         out
);
    assign out = in[sel];
endmodule
