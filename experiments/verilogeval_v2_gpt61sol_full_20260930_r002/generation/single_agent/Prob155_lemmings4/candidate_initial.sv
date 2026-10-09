module TopModule (
    input logic clk, areset,
    input logic bump_left, bump_right, ground, dig,
    output logic walk_left, walk_right, aaah, digging
);
    typedef enum logic [2:0] {LEFT, RIGHT, FALL_LEFT, FALL_RIGHT,
                              DIG_LEFT, DIG_RIGHT, DEAD} state_t;
    state_t state_r, state_n;
    logic [4:0] fall_cycles_r;

    always_comb begin
        state_n = state_r;
        case (state_r)
            LEFT: begin
                if (!ground) state_n = FALL_LEFT;
                else if (dig) state_n = DIG_LEFT;
                else if (bump_left) state_n = RIGHT;
            end
            RIGHT: begin
                if (!ground) state_n = FALL_RIGHT;
                else if (dig) state_n = DIG_RIGHT;
                else if (bump_right) state_n = LEFT;
            end
            DIG_LEFT: if (!ground) state_n = FALL_LEFT;
            DIG_RIGHT: if (!ground) state_n = FALL_RIGHT;
            FALL_LEFT: begin
                if (ground) begin
                    if (fall_cycles_r > 5'd20) state_n = DEAD;
                    else state_n = LEFT;
                end
            end
            FALL_RIGHT: begin
                if (ground) begin
                    if (fall_cycles_r > 5'd20) state_n = DEAD;
                    else state_n = RIGHT;
                end
            end
            DEAD: state_n = DEAD;
            default: state_n = LEFT;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset) begin
            state_r <= LEFT;
            fall_cycles_r <= 5'd0;
        end else begin
            state_r <= state_n;
            if (state_r == FALL_LEFT || state_r == FALL_RIGHT) begin
                if (!ground && fall_cycles_r < 5'd21)
                    fall_cycles_r <= fall_cycles_r + 5'd1;
            end else if (state_n == FALL_LEFT || state_n == FALL_RIGHT)
                fall_cycles_r <= 5'd1;
            else
                fall_cycles_r <= 5'd0;
        end
    end

    assign walk_left = (state_r == LEFT);
    assign walk_right = (state_r == RIGHT);
    assign aaah = (state_r == FALL_LEFT || state_r == FALL_RIGHT);
    assign digging = (state_r == DIG_LEFT || state_r == DIG_RIGHT);
endmodule
