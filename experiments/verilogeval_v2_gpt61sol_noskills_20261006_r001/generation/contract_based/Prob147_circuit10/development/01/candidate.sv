module TopModule (
    input wire clk,
    input wire a,
    input wire b,
    output wire q,
    output reg state
);
    always @(posedge clk)
        state <= a & b;
    assign q = a ^ b ^ state;
endmodule
