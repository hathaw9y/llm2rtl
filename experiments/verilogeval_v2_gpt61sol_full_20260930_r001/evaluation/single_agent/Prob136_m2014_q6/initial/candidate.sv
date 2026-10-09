module TopModule (
    input  logic clk,
    input  logic reset,
    input  logic w,
    output logic z
);
    typedef enum logic [2:0] {A, B, C, D, E, F} state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = A;
        case (state_r)
            A: if (w) state_n = A; else state_n = B;
            B: if (w) state_n = D; else state_n = C;
            C: if (w) state_n = D; else state_n = E;
            D: if (w) state_n = A; else state_n = F;
            E: if (w) state_n = D; else state_n = E;
            F: if (w) state_n = D; else state_n = C;
            default: state_n = A;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset)
            state_r <= A;
        else
            state_r <= state_n;
    end

    assign z = (state_r == E) || (state_r == F);
endmodule
