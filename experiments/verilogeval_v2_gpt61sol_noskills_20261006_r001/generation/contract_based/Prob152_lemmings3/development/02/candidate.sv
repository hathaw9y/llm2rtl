module TopModule (
    input clk,
    input areset,
    input bump_left,
    input bump_right,
    input ground,
    input dig,
    output walk_left,
    output walk_right,
    output aaah,
    output digging
);
    typedef enum logic [2:0] {
        WALK_L, WALK_R, FALL_L, FALL_R, DIG_L, DIG_R
    } state_t;
    state_t state, next_state;

    always @* begin
        next_state = state;
        case (state)
            WALK_L: begin
                if (!ground) next_state = FALL_L;
                else if (dig) next_state = DIG_L;
                else if (bump_left) next_state = WALK_R;
            end
            WALK_R: begin
                if (!ground) next_state = FALL_R;
                else if (dig) next_state = DIG_R;
                else if (bump_right) next_state = WALK_L;
            end
            FALL_L: begin
                if (ground) next_state = WALK_L;
            end
            FALL_R: begin
                if (ground) next_state = WALK_R;
            end
            DIG_L: begin
                if (!ground) next_state = FALL_L;
            end
            DIG_R: begin
                if (!ground) next_state = FALL_R;
            end
            default: next_state = WALK_L;
        endcase
    end

    always @(posedge clk or posedge areset) begin
        if (areset) state <= WALK_L;
        else state <= next_state;
    end

    assign walk_left = (state == WALK_L);
    assign walk_right = (state == WALK_R);
    assign aaah = (state == FALL_L) || (state == FALL_R);
    assign digging = (state == DIG_L) || (state == DIG_R);
endmodule
