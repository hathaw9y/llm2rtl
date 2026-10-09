module TopModule (
    input wire in,
    input wire [1:0] state,
    output reg [1:0] next_state,
    output wire out
);
    localparam [1:0] A = 2'b00, B = 2'b01,
                     C = 2'b10, D = 2'b11;

    always @* begin
        next_state = 2'bxx;
        case (state)
            A: begin
                if (in) next_state = B;
                else    next_state = A;
            end
            B: begin
                if (in) next_state = B;
                else    next_state = C;
            end
            C: begin
                if (in) next_state = D;
                else    next_state = A;
            end
            D: begin
                if (in) next_state = B;
                else    next_state = C;
            end
            default: next_state = 2'bxx;
        endcase
    end

    assign out = (state == D);
endmodule
