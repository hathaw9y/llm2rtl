module TopModule (
    input  logic clk,
    input  logic resetn,
    input  logic x,
    input  logic y,
    output logic f,
    output logic g
);
    typedef enum logic [3:0] {
        A, F_PULSE, WAIT_X, SEEN_1, SEEN_10,
        Y_FIRST, Y_SECOND, HOLD_HIGH, HOLD_LOW
    } state_t;
    state_t state_r, state_n;

    always_ff @(posedge clk) begin
        if (!resetn)
            state_r <= A;
        else
            state_r <= state_n;
    end

    always_comb begin
        state_n = state_r;
        case (state_r)
            A:          state_n = F_PULSE;
            F_PULSE:    state_n = WAIT_X;
            WAIT_X:     if (x) state_n = SEEN_1;
            SEEN_1:     if (!x) state_n = SEEN_10;
            SEEN_10: begin
                if (x) state_n = Y_FIRST;
                else   state_n = WAIT_X;
            end
            Y_FIRST: begin
                if (y) state_n = HOLD_HIGH;
                else   state_n = Y_SECOND;
            end
            Y_SECOND: begin
                if (y) state_n = HOLD_HIGH;
                else   state_n = HOLD_LOW;
            end
            HOLD_HIGH: state_n = HOLD_HIGH;
            HOLD_LOW:  state_n = HOLD_LOW;
            default:   state_n = A;
        endcase
    end

    assign f = (state_r == F_PULSE);
    assign g = (state_r == Y_FIRST) || (state_r == Y_SECOND) ||
               (state_r == HOLD_HIGH);
endmodule
