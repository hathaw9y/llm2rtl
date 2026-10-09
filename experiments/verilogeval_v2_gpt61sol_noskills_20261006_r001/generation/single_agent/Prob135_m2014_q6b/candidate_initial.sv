module TopModule (
    input wire [2:0] y,
    input wire w,
    output reg Y1
);
    // Bit 1 of the next state, using A through F = 000 through 101.
    always @* begin
        case (y)
            3'b000: Y1 = 1'b0; // B or A
            3'b001: Y1 = 1'b1; // C or D
            3'b010: Y1 = w;    // E or D
            3'b011: Y1 = 1'b0; // F or A
            3'b100: Y1 = w;    // E or D
            3'b101: Y1 = 1'b1; // C or D
            default: Y1 = 1'bx; // Unspecified state codes
        endcase
    end
endmodule
