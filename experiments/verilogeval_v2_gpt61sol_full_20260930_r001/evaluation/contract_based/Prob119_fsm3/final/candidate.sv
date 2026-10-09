module TopModule (
    input  logic clk,
    input  logic areset,
    input  logic in,
    output logic out
);
    typedef enum logic [1:0] {A = 2'b00, B = 2'b01,
                              C = 2'b10, D = 2'b11} state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = A;
        case (state_r)
            A: if (in) state_n = B; else state_n = A;
            B: if (in) state_n = B; else state_n = C;
            C: if (in) state_n = D; else state_n = A;
            D: if (in) state_n = B; else state_n = C;
            default: state_n = A;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset) state_r <= A;
        else        state_r <= state_n;
    end

    assign out = (state_r == D);
endmodule
