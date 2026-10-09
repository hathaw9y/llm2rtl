module TopModule (
    input wire [2:0] y,
    input wire w,
    output reg Y1
);
    always @* begin
        case (y)
            3'b000: Y1 = 1'b0;
            3'b001: Y1 = 1'b1;
            3'b010: Y1 = w;
            3'b011: Y1 = 1'b0;
            3'b100: Y1 = w;
            3'b101: Y1 = 1'b1;
            default: Y1 = 1'bx;
        endcase
    end
endmodule
