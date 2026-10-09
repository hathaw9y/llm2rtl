module TopModule (
    input wire clk,
    input wire ar,
    input wire d,
    output reg q
);
    always @(posedge clk or posedge ar) begin
        if (ar)
            q <= 1'b0;
        else
            q <= d;
    end
endmodule
