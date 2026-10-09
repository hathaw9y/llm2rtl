module ModuleA(input wire x, input wire y, output wire z);
    assign z = (x ^ y) & x;
endmodule

module ModuleB(input wire x, input wire y, output wire z);
    assign z = ~(x ^ y);
endmodule

module TopModule(input wire x, input wire y, output wire z);
    wire a1, a2, b1, b2;
    ModuleA first_a (.x(x), .y(y), .z(a1));
    ModuleA second_a (.x(x), .y(y), .z(a2));
    ModuleB first_b (.x(x), .y(y), .z(b1));
    ModuleB second_b (.x(x), .y(y), .z(b2));
    assign z = (a1 | b1) ^ (a2 & b2);
endmodule
