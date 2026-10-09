module TopModule (
    input  logic a,
    input  logic b,
    input  logic c,
    input  logic d,
    input  logic e,
    output logic [24:0] out
);
    // Rows and columns both follow a, b, c, d, e, from MSB to LSB.
    assign out = ~({{5{a}}, {5{b}}, {5{c}}, {5{d}}, {5{e}}}
                 ^ {5{a, b, c, d, e}});
endmodule
