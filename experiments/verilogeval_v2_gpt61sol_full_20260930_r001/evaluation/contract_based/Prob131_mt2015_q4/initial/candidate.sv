module top_module (
    input  logic x,
    input  logic y,
    output logic z
);
    logic a_first, a_second;
    logic b_first, b_second;
    logic or_result, and_result;

    candidate_a a1 (.x(x), .y(y), .z(a_first));
    candidate_a a2 (.x(x), .y(y), .z(a_second));
    candidate_b b1 (.x(x), .y(y), .z(b_first));
    candidate_b b2 (.x(x), .y(y), .z(b_second));

    assign or_result = a_first | b_first;
    assign and_result = a_second & b_second;
    assign z = or_result ^ and_result;
endmodule

module candidate_a (
    input  logic x,
    input  logic y,
    output logic z
);
    assign z = (x ^ y) & x;
endmodule

module candidate_b (
    input  logic x,
    input  logic y,
    output logic z
);
    assign z = ~(x ^ y);
endmodule
