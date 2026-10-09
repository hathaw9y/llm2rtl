module TopModule (
    input  logic       in,
    input  logic [1:0] state,
    output logic [1:0] next_state,
    output logic       out
);
    localparam logic [1:0] A = 2'b00,
                           B = 2'b01,
                           C = 2'b10,
                           D = 2'b11;

    always_comb begin
        next_state = A;
        out = 1'b0;
        case (state)
            A: next_state = in ? B : A;
            B: next_state = in ? B : C;
            C: next_state = in ? D : A;
            D: begin
                next_state = in ? B : C;
                out = 1'b1;
            end
            default: begin
                next_state = A;
                out = 1'b0;
            end
        endcase
    end
endmodule
