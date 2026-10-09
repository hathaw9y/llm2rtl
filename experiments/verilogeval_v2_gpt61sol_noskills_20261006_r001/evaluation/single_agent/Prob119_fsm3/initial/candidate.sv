module TopModule (
    input wire clk,
    input wire areset,
    input wire in,
    output wire out
);
    localparam [1:0] A = 2'd0, B = 2'd1, C = 2'd2, D = 2'd3;
    reg [1:0] state, next_state;

    always @* begin
        case (state)
            A: begin if (in) next_state = B; else next_state = A; end
            B: begin if (in) next_state = B; else next_state = C; end
            C: begin if (in) next_state = D; else next_state = A; end
            D: begin if (in) next_state = B; else next_state = C; end
            default: next_state = A;
        endcase
    end

    always @(posedge clk or posedge areset) begin
        if (areset) state <= A;
        else state <= next_state;
    end

    assign out = (state == D);
endmodule
