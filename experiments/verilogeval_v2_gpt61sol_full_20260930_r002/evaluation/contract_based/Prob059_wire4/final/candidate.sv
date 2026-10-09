module TopModule (
    input logic a,
    input logic b,
    input logic c,
    output wire w,
    output wire x,
    output wire y,
    output wire z
);
    assign w = a;
    assign x = b;
    assign y = b;
    assign z = c;
endmodule
