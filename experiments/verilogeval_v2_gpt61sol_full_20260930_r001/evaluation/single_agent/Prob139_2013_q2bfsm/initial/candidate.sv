module TopModule (
    input  logic clk,
    input  logic resetn,
    input  logic x,
    input  logic y,
    output logic f,
    output logic g
);
    typedef enum logic [3:0] {
        A, PULSE_F, WAIT_X, SEEN_1, SEEN_10,
        WAIT_Y_FIRST, WAIT_Y_SECOND, HOLD_G, STOP_G
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
            A:             state_n = PULSE_F;
            PULSE_F:       state_n = WAIT_X;
            WAIT_X:        if (x) state_n = SEEN_1;
            SEEN_1:        if (!x) state_n = SEEN_10;
            SEEN_10:       state_n = x ? WAIT_Y_FIRST : WAIT_X;
            WAIT_Y_FIRST:  state_n = y ? HOLD_G : WAIT_Y_SECOND;
            WAIT_Y_SECOND: state_n = y ? HOLD_G : STOP_G;
            HOLD_G:        state_n = HOLD_G;
            STOP_G:        state_n = STOP_G;
            default:       state_n = A;
        endcase
    end

    assign f = (state_r == PULSE_F);
    assign g = (state_r == WAIT_Y_FIRST) ||
               (state_r == WAIT_Y_SECOND) || (state_r == HOLD_G);
endmodule
