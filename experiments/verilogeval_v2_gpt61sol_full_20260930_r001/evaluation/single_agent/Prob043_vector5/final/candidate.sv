module TopModule (
    input  logic a,
    input  logic b,
    input  logic c,
    input  logic d,
    input  logic e,
    output logic [24:0] out
);
    assign out = {
        {5{a}} ~^ {a, b, c, d, e},
        {5{b}} ~^ {a, b, c, d, e},
        {5{c}} ~^ {a, b, c, d, e},
        {5{d}} ~^ {a, b, c, d, e},
        {5{e}} ~^ {a, b, c, d, e}
    };
endmodule
