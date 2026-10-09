module TopModule (
    input wire x,
    input wire y,
    output wire z
);
    wire a_first, a_second, b_first, b_second;
    ModuleA a1 (.x(x), .y(y), .z(a_first));
    ModuleA a2 (.x(x), .y(y), .z(a_second));
    ModuleB b1 (.x(x), .y(y), .z(b_first));
    ModuleB b2 (.x(x), .y(y), .z(b_second));
    assign z = (a_first | b_first) ^ (a_second & b_second);
endmodule

module ModuleA (input wire x, input wire y, output wire z);
    assign z = (x ^ y) & x;
endmodule

module ModuleB (input wire x, input wire y, output wire z);
    assign z = ~(x ^ y);
endmodule
