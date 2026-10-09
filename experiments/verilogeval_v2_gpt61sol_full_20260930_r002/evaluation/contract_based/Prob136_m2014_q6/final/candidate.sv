module TopModule (
    input logic clk,
    input logic reset,
    input logic w,
    output logic z
);
    typedef enum logic [2:0] {A, B, C, D, E, F} state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = state_r;
        case (state_r)
            A: begin if (w) state_n = A; else state_n = B; end
            B: begin if (w) state_n = D; else state_n = C; end
            C: begin if (w) state_n = D; else state_n = E; end
            D: begin if (w) state_n = A; else state_n = F; end
            E: begin if (w) state_n = D; else state_n = E; end
            F: begin if (w) state_n = D; else state_n = C; end
            default: state_n = A;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) state_r <= A;
        else state_r <= state_n;
    end

    assign z = (state_r == E) || (state_r == F);
endmodule
