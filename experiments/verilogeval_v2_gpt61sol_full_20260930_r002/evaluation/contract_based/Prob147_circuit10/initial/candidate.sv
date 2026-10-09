module TopModule (
    input logic clk,
    input logic a,
    input logic b,
    output logic q,
    output logic state
);
    always_ff @(posedge clk)
        state <= a & b;

    assign q = a ^ b ^ state;
endmodule
