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
    logic a_first_w, b_first_w;
    logic a_second_w, b_second_w;
    logic or_w, and_w;

    module_a a_first (.x(x), .y(y), .z(a_first_w));
    module_b b_first (.x(x), .y(y), .z(b_first_w));
    module_a a_second (.x(x), .y(y), .z(a_second_w));
    module_b b_second (.x(x), .y(y), .z(b_second_w));

    assign or_w = a_first_w | b_first_w;
    assign and_w = a_second_w & b_second_w;
    assign z = or_w ^ and_w;
endmodule
