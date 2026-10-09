module TopModule (
    input wire clk,
    input wire a,
    output reg q
);
    always @(posedge clk)
        q <= ~a;
endmodule
