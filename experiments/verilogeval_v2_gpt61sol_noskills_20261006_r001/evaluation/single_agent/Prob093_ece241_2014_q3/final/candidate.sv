module TopModule (
    input wire c,
    input wire d,
    output wire [3:0] mux_in
);
    // Each conditional implements one 2-to-1 multiplexer.
    assign mux_in[0] = c ? 1'b1 : d;
    assign mux_in[1] = 1'b0;
    assign mux_in[2] = d ? c : 1'b1;
    assign mux_in[3] = c ? d : 1'b0;
endmodule
