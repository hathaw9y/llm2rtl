module TopModule (
    input  logic a,
    input  logic b,
    input  logic c,
    input  logic d,
    output logic out
);
    // Groups: abcd={0,2,4,6}, {0,1,8,9}, and {7,11,15}.
    assign out = (~a & ~d) | (~b & ~c) | (c & d & (a | b));
endmodule
