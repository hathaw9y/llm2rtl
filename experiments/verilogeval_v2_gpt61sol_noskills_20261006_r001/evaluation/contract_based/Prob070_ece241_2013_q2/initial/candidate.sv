module TopModule (
    input  wire a,
    input  wire b,
    input  wire c,
    input  wire d,
    output wire out_sop,
    output wire out_pos
);
    assign out_sop = (~a & ~b & c) | (c & d);
    assign out_pos = c & (~a | d) & (~b | d);
endmodule
