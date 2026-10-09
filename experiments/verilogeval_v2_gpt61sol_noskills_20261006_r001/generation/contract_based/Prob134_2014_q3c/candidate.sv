module TopModule (
    input wire clk,
    input wire x,
    input wire [2:0] y,
    output reg Y0,
    output reg z
);
    always @* begin
        Y0 = 1'bx;
        z = 1'bx;
        case (y)
            3'b000: begin Y0 = x;  z = 1'b0; end
            3'b001: begin Y0 = ~x; z = 1'b0; end
            3'b010: begin Y0 = x;  z = 1'b0; end
            3'b011: begin Y0 = ~x; z = 1'b1; end
            3'b100: begin Y0 = ~x; z = 1'b1; end
            default: begin Y0 = 1'bx; z = 1'bx; end
        endcase
    end
endmodule
