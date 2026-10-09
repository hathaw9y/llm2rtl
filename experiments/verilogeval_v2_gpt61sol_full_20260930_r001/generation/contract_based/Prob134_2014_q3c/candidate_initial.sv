module TopModule (
    input  logic       clk,
    input  logic       x,
    input  logic [2:0] y,
    output logic       Y0,
    output logic       z
);
    // y is the externally supplied present state; no state register is needed.
    always_comb begin
        Y0 = 1'b0;
        z = 1'b0;
        case (y)
            3'b000: Y0 = x;
            3'b001: Y0 = ~x;
            3'b010: Y0 = x;
            3'b011: begin
                Y0 = ~x;
                z = 1'b1;
            end
            3'b100: begin
                Y0 = ~x;
                z = 1'b1;
            end
            default: begin
                Y0 = 1'b0;
                z = 1'b0;
            end
        endcase
    end
endmodule
