module TopModule (
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic [7:0] c,
    input  logic [7:0] d,
    output logic [7:0] min
);
    logic [7:0] min_ab_w;
    logic [7:0] min_cd_w;

    assign min_ab_w = (a < b) ? a : b;
    assign min_cd_w = (c < d) ? c : d;
    assign min = (min_ab_w < min_cd_w) ? min_ab_w : min_cd_w;
endmodule
