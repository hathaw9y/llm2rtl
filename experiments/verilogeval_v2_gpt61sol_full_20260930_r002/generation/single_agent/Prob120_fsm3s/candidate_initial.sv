module TopModule (
    input logic clk,
    input logic reset,
    input logic in,
    output logic out
);
    typedef enum logic [1:0] {A, B, C, D} state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = A;
        case (state_r)
            A: begin
                if (in) state_n = B;
                else state_n = A;
            end
            B: begin
                if (in) state_n = B;
                else state_n = C;
            end
            C: begin
                if (in) state_n = D;
                else state_n = A;
            end
            D: begin
                if (in) state_n = B;
                else state_n = C;
            end
            default: state_n = A;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) state_r <= A;
        else state_r <= state_n;
    end

    assign out = (state_r == D);
endmodule
