module TopModule (
    input clk,
    input areset,
    input bump_left,
    input bump_right,
    input ground,
    output walk_left,
    output walk_right,
    output aaah
);
    typedef enum logic [1:0] {LEFT, RIGHT, FALL_LEFT, FALL_RIGHT} state_t;
    state_t state, next_state;

    always_comb begin
        next_state = state;
        case (state)
            LEFT: begin
                if (!ground) next_state = FALL_LEFT;
                else if (bump_left) next_state = RIGHT;
            end
            RIGHT: begin
                if (!ground) next_state = FALL_RIGHT;
                else if (bump_right) next_state = LEFT;
            end
            FALL_LEFT: begin
                if (ground) next_state = LEFT;
            end
            FALL_RIGHT: begin
                if (ground) next_state = RIGHT;
            end
            default: next_state = LEFT;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset) state <= LEFT;
        else state <= next_state;
    end

    assign walk_left = (state == LEFT);
    assign walk_right = (state == RIGHT);
    assign aaah = (state == FALL_LEFT) || (state == FALL_RIGHT);
endmodule
