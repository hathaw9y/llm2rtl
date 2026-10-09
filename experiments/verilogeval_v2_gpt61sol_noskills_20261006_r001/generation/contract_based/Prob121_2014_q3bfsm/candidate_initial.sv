module TopModule (
    input wire clk,
    input wire reset,
    input wire x,
    output reg z
);
    reg [2:0] y;
    reg [2:0] next_y;

    always @* begin
        case (y)
            3'b000: begin if (x) next_y = 3'b001; else next_y = 3'b000; end
            3'b001: begin if (x) next_y = 3'b100; else next_y = 3'b001; end
            3'b010: begin if (x) next_y = 3'b001; else next_y = 3'b010; end
            3'b011: begin if (x) next_y = 3'b010; else next_y = 3'b001; end
            3'b100: begin if (x) next_y = 3'b100; else next_y = 3'b011; end
            default: next_y = 3'b000;
        endcase
    end

    always @(posedge clk) begin
        if (reset) y <= 3'b000;
        else y <= next_y;
    end

    always @* begin
        case (y)
            3'b000, 3'b001, 3'b010: z = 1'b0;
            3'b011, 3'b100: z = 1'b1;
            default: z = 1'bx;
        endcase
    end
endmodule
