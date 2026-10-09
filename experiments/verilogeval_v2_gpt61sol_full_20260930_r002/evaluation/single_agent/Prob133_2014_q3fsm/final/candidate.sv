module TopModule (
    input logic clk,
    input logic reset,
    input logic s,
    input logic w,
    output logic z
);
    typedef enum logic [2:0] {
        A, B_ZERO, B_MATCH, C_ZERO, C_ONE, D_ZERO, D_ONE, D_TWO
    } state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = A;
        case (state_r)
            A: begin
                if (s) state_n = B_ZERO;
                else state_n = A;
            end
            B_ZERO, B_MATCH: begin
                if (w) state_n = C_ONE;
                else state_n = C_ZERO;
            end
            C_ZERO: begin
                if (w) state_n = D_ONE;
                else state_n = D_ZERO;
            end
            C_ONE: begin
                if (w) state_n = D_TWO;
                else state_n = D_ONE;
            end
            D_ZERO: state_n = B_ZERO;
            D_ONE: begin
                if (w) state_n = B_MATCH;
                else state_n = B_ZERO;
            end
            D_TWO: begin
                if (w) state_n = B_ZERO;
                else state_n = B_MATCH;
            end
            default: state_n = A;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) state_r <= A;
        else state_r <= state_n;
    end

    assign z = (state_r == B_MATCH);
endmodule
