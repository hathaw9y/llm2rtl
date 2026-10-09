module TopModule (
    input logic clk,
    input logic resetn,
    input logic x,
    input logic y,
    output logic f,
    output logic g
);
    typedef enum logic [3:0] {
        A, PULSE, WAIT_X, HAVE_1, HAVE_10,
        CHECK_Y_FIRST, CHECK_Y_SECOND, HOLD_ON, HOLD_OFF
    } state_t;
    state_t state, next_state;

    always_comb begin
        next_state = state;
        case (state)
            A: next_state = PULSE;
            PULSE: begin
                if (x) next_state = HAVE_1;
                else next_state = WAIT_X;
            end
            WAIT_X: begin
                if (x) next_state = HAVE_1;
                else next_state = WAIT_X;
            end
            HAVE_1: begin
                if (x) next_state = HAVE_1;
                else next_state = HAVE_10;
            end
            HAVE_10: begin
                if (x) next_state = CHECK_Y_FIRST;
                else next_state = WAIT_X;
            end
            CHECK_Y_FIRST: begin
                if (y) next_state = HOLD_ON;
                else next_state = CHECK_Y_SECOND;
            end
            CHECK_Y_SECOND: begin
                if (y) next_state = HOLD_ON;
                else next_state = HOLD_OFF;
            end
            HOLD_ON: next_state = HOLD_ON;
            HOLD_OFF: next_state = HOLD_OFF;
            default: next_state = A;
        endcase
    end

    always_ff @(posedge clk) begin
        if (!resetn) state <= A;
        else state <= next_state;
    end

    assign f = (state == PULSE);
    assign g = (state == CHECK_Y_FIRST) || (state == CHECK_Y_SECOND) ||
               (state == HOLD_ON);
endmodule
