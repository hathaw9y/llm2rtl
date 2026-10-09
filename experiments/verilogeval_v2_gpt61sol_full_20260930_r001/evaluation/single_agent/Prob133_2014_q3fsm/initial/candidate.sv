module TopModule (
    input  logic clk,
    input  logic reset,
    input  logic s,
    input  logic w,
    output logic z
);
    typedef enum logic [2:0] {
        A, B_ZERO, B_PASS, C_ZERO, C_ONE, D_ZERO, D_ONE, D_TWO
    } state_t;
    state_t state_r, state_n;

    // B states start a new window and report the preceding window.
    assign z = (state_r == B_PASS);

    always_comb begin
        state_n = A;
        case (state_r)
            A:      state_n = s ? B_ZERO : A;
            B_ZERO, B_PASS: state_n = w ? C_ONE : C_ZERO;
            C_ZERO: state_n = w ? D_ONE : D_ZERO;
            C_ONE:  state_n = w ? D_TWO : D_ONE;
            D_ZERO: state_n = B_ZERO;
            D_ONE:  state_n = w ? B_PASS : B_ZERO;
            D_TWO:  state_n = w ? B_ZERO : B_PASS;
            default: state_n = A;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset)
            state_r <= A;
        else
            state_r <= state_n;
    end
endmodule
