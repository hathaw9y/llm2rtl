module TopModule (
    input logic clk,
    input logic resetn,
    input logic x,
    input logic y,
    output logic f,
    output logic g
);
    typedef enum logic [3:0] {
        A, PULSE_F, WAIT_X, X_ONE, X_ONE_ZERO,
        Y_FIRST, Y_SECOND, HOLD_HIGH, HOLD_LOW
    } state_t;
    state_t state_r, state_n;

    always_ff @(posedge clk) begin
        if (!resetn) state_r <= A;
        else state_r <= state_n;
    end

    always_comb begin
        state_n = state_r;
        case (state_r)
            A: state_n = PULSE_F;
            PULSE_F: state_n = WAIT_X;
            WAIT_X: begin
                if (x) state_n = X_ONE;
                else state_n = WAIT_X;
            end
            X_ONE: begin
                if (x) state_n = X_ONE;
                else state_n = X_ONE_ZERO;
            end
            X_ONE_ZERO: begin
                if (x) state_n = Y_FIRST;
                else state_n = WAIT_X;
            end
            Y_FIRST: begin
                if (y) state_n = HOLD_HIGH;
                else state_n = Y_SECOND;
            end
            Y_SECOND: begin
                if (y) state_n = HOLD_HIGH;
                else state_n = HOLD_LOW;
            end
            HOLD_HIGH: state_n = HOLD_HIGH;
            HOLD_LOW: state_n = HOLD_LOW;
            default: state_n = A;
        endcase
    end
    assign f = (state_r == PULSE_F);
    assign g = (state_r == Y_FIRST) || (state_r == Y_SECOND) ||
               (state_r == HOLD_HIGH);
endmodule
