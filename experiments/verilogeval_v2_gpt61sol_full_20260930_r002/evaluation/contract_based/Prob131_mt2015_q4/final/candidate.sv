module module_a (
    input logic x,
    input logic y,
    output logic z
);
    assign z = (x ^ y) & x;
endmodule

module module_b (
    input logic x,
    input logic y,
    output logic z
);
    assign z = ~(x ^ y);
endmodule

module TopModule (
    input logic x,
    input logic y,
    output logic z
);
    logic a1, a2, b1, b2;
    module_a a_first  (.x(x), .y(y), .z(a1));
    module_a a_second (.x(x), .y(y), .z(a2));
    module_b b_first  (.x(x), .y(y), .z(b1));
    module_b b_second (.x(x), .y(y), .z(b2));
    assign z = (a1 | b1) ^ (a2 & b2);
endmodule
