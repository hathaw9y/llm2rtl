module TopModule (
    input wire a,
    input wire b,
    input wire c,
    input wire d,
    output wire out,
    output wire out_n
);
    wire ab_w;
    wire cd_w;

    assign ab_w = a & b;
    assign cd_w = c & d;
    assign out = ab_w | cd_w;
    assign out_n = ~out;
endmodule
