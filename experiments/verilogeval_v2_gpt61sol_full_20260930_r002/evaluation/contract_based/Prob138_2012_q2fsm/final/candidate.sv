module TopModule (
    input logic clk,
    input logic reset,
    input logic w,
    output logic z
);
    typedef enum logic [2:0] {A, B, C, D, E, F} state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = A;
        case (state_r)
            A: begin if (w) state_n = B; else state_n = A; end
            B: begin if (w) state_n = C; else state_n = D; end
            C: begin if (w) state_n = E; else state_n = D; end
            D: begin if (w) state_n = F; else state_n = A; end
            E: begin if (w) state_n = E; else state_n = D; end
            F: begin if (w) state_n = C; else state_n = D; end
            default: state_n = A;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) state_r <= A;
        else state_r <= state_n;
    end

    assign z = (state_r == E) || (state_r == F);
endmodule
