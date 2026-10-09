module TopModule (
    input  logic [2:0] y,
    input  logic       w,
    output logic       Y1
);
    // Bit 1 of the next state, using A..F = 000..101.
    always_comb begin
        case (y)
            3'b000: Y1 = 1'b0;
            3'b001: Y1 = 1'b1;
            3'b010: Y1 = w;
            3'b011: Y1 = 1'b0;
            3'b100: Y1 = w;
            3'b101: Y1 = 1'b1;
            default: Y1 = 1'b0;
        endcase
    end
endmodule
