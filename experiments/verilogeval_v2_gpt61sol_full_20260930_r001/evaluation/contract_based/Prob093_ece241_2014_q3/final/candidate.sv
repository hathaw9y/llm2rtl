module TopModule (
    input  logic       c,
    input  logic       d,
    output logic [3:0] mux_in
);
    // External mux selector {a,b}: 00, 01, 10, 11.
    assign mux_in[0] = c ? 1'b1 : d;
    assign mux_in[1] = 1'b0;
    assign mux_in[2] = d ? c : 1'b1;
    assign mux_in[3] = c ? d : 1'b0;
endmodule
