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
        WALK_L, WALK_R, DIG_L, DIG_R, FALL_L, FALL_R, DEAD
    } state_t;
    state_t state_r, state_n;
    logic [4:0] fall_count_r;

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
            DIG_L: begin
                if (!ground) state_n = FALL_L;
            end
            DIG_R: begin
                if (!ground) state_n = FALL_R;
            end
            FALL_L: begin
                if (ground) begin
                    if (fall_count_r > 5'd20) state_n = DEAD;
                    else state_n = WALK_L;
                end
            end
            FALL_R: begin
                if (ground) begin
                    if (fall_count_r > 5'd20) state_n = DEAD;
                    else state_n = WALK_R;
                end
            end
            DEAD: state_n = DEAD;
            default: state_n = WALK_L;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset) begin
            state_r <= WALK_L;
            fall_count_r <= 5'd0;
        end else begin
            state_r <= state_n;
            if ((state_n == FALL_L) || (state_n == FALL_R)) begin
                if ((state_r != FALL_L) && (state_r != FALL_R))
                    fall_count_r <= 5'd1;
                else if (fall_count_r < 5'd21)
                    fall_count_r <= fall_count_r + 5'd1;
            end else begin
                fall_count_r <= 5'd0;
            end
        end
    end

    assign walk_left = (state_r == WALK_L);
    assign walk_right = (state_r == WALK_R);
    assign aaah = (state_r == FALL_L) || (state_r == FALL_R);
    assign digging = (state_r == DIG_L) || (state_r == DIG_R);
endmodule
