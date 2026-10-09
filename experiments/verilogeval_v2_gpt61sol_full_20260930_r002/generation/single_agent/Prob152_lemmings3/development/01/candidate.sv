module TopModule (
    input logic clk,
    input logic areset,
    input logic bump_left,
    input logic bump_right,
    input logic ground,
    input logic dig,
    output logic walk_left,
    output logic walk_right,
    output logic aaah,
    output logic digging
);
    typedef enum logic [2:0] {
        WALK_L, WALK_R, FALL_L, FALL_R, DIG_L, DIG_R
    } state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = state_r;
        case (state_r)
            WALK_L: begin
                if (!ground) state_n = FALL_L;
                else if (dig) state_n = DIG_L;
                else if (bump_left) state_n = WALK_R;
            end
            WALK_R: begin
                if (!ground) state_n = FALL_R;
                else if (dig) state_n = DIG_R;
                else if (bump_right) state_n = WALK_L;
            end
            FALL_L: if (ground) state_n = WALK_L;
            FALL_R: if (ground) state_n = WALK_R;
            DIG_L: if (!ground) state_n = FALL_L;
            DIG_R: if (!ground) state_n = FALL_R;
            default: state_n = WALK_L;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset) state_r <= WALK_L;
        else state_r <= state_n;
    end

    assign walk_left = (state_r == WALK_L);
    assign walk_right = (state_r == WALK_R);
    assign aaah = (state_r == FALL_L) || (state_r == FALL_R);
    assign digging = (state_r == DIG_L) || (state_r == DIG_R);
endmodule
