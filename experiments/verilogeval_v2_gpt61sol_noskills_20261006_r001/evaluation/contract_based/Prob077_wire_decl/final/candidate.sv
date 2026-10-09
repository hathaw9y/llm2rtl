module TopModule (
    input wire a,
    input wire b,
    input wire c,
    input wire d,
    output wire out,
    output wire out_n
);
    wire ab;
    wire cd;

    assign ab = a & b;
    assign cd = c & d;
    assign out = ab | cd;
    assign out_n = ~out;
endmodule
