module TopModule (
    input wire clk,
    input wire in,
    output reg out
);
    always @(posedge clk)
        out <= in ^ out;
endmodule
