module TopModule (
    input  logic a,
    input  logic b,
    input  logic c,
    input  logic d,
    output logic out
);
    // All specified K-map cells are covered; don't-care cells choose 1.
    assign out = a | (c & ~b);
endmodule
