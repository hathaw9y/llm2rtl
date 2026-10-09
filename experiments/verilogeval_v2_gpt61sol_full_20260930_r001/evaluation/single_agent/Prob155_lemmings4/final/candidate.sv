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
        WALK_LEFT, WALK_RIGHT, DIG_LEFT, DIG_RIGHT,
        FALL_LEFT, FALL_RIGHT, SPLAT
    } state_t;
    state_t state_r, state_n;
    logic [4:0] fall_count_r;

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
            DIG_LEFT: if (!ground) state_n = FALL_LEFT;
            DIG_RIGHT: if (!ground) state_n = FALL_RIGHT;
            FALL_LEFT: begin
                if (ground) begin
                    if (fall_count_r > 5'd20) state_n = SPLAT;
                    else state_n = WALK_LEFT;
                end
            end
            FALL_RIGHT: begin
                if (ground) begin
                    if (fall_count_r > 5'd20) state_n = SPLAT;
                    else state_n = WALK_RIGHT;
                end
            end
            SPLAT: state_n = SPLAT;
            default: state_n = WALK_LEFT;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset) begin
            state_r <= WALK_LEFT;
            fall_count_r <= 5'd0;
        end else begin
            state_r <= state_n;
            // Count complete falling intervals, including the entry interval.
            // Saturation preserves the fatal-fall flag for arbitrarily long falls.
            if (state_n == FALL_LEFT || state_n == FALL_RIGHT) begin
                if (state_r != FALL_LEFT && state_r != FALL_RIGHT)
                    fall_count_r <= 5'd1;
                else if (fall_count_r < 5'd21)
                    fall_count_r <= fall_count_r + 5'd1;
            end else begin
                fall_count_r <= 5'd0;
            end
        end
    end

    always_comb begin
        walk_left = (state_r == WALK_LEFT);
        walk_right = (state_r == WALK_RIGHT);
        aaah = (state_r == FALL_LEFT || state_r == FALL_RIGHT);
        digging = (state_r == DIG_LEFT || state_r == DIG_RIGHT);
    end
endmodule
