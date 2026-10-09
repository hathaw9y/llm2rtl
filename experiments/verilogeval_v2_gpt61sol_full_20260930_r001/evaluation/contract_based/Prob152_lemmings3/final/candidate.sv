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
        WALK_LEFT, WALK_RIGHT, FALL_LEFT, FALL_RIGHT, DIG_LEFT, DIG_RIGHT
    } state_t;
    state_t state_r, state_n;

    always_ff @(posedge clk or posedge areset) begin
        if (areset)
            state_r <= WALK_LEFT;
        else
            state_r <= state_n;
    end

    always_comb begin
        state_n = state_r;
        case (state_r)
            WALK_LEFT: begin
                if (!ground) state_n = FALL_LEFT;
                else if (dig) state_n = DIG_LEFT;
                else if (bump_left) state_n = WALK_RIGHT;
            end
            WALK_RIGHT: begin
                if (!ground) state_n = FALL_RIGHT;
                else if (dig) state_n = DIG_RIGHT;
                else if (bump_right) state_n = WALK_LEFT;
            end
            FALL_LEFT: if (ground) state_n = WALK_LEFT;
            FALL_RIGHT: if (ground) state_n = WALK_RIGHT;
            DIG_LEFT: if (!ground) state_n = FALL_LEFT;
            DIG_RIGHT: if (!ground) state_n = FALL_RIGHT;
            default: state_n = WALK_LEFT;
        endcase
    end

    always_comb begin
        walk_left = (state_r == WALK_LEFT);
        walk_right = (state_r == WALK_RIGHT);
        aaah = (state_r == FALL_LEFT) || (state_r == FALL_RIGHT);
        digging = (state_r == DIG_LEFT) || (state_r == DIG_RIGHT);
    end
endmodule
