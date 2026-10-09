module TopModule (
    input  logic a,
    input  logic b,
    input  logic c,
    input  logic d,
    output logic out_sop,
    output logic out_pos
);
    // Prime implicants cover {2,3} and {3,7,11,15}.
    assign out_sop = (~a & ~b & c) | (c & d);
    // Zero groups yield c, (~a | d), and (~b | d).
    assign out_pos = c & (~a | d) & (~b | d);
endmodule
