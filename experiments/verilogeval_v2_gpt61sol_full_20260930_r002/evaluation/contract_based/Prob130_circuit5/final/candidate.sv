module TopModule (
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic [3:0] c,
    input  logic [3:0] d,
    input  logic [3:0] e,
    output logic [3:0] q
);
    always_comb begin
        case (c)
            4'h0: q = b;
            4'h1: q = e;
            4'h2: q = a;
            4'h3: q = d;
            4'h4, 4'h5, 4'h6, 4'h7,
            4'h8, 4'h9, 4'ha, 4'hb,
            4'hc, 4'hd, 4'he, 4'hf: q = 4'hf;
            default: q = 4'hx;
        endcase
    end
endmodule
