module TopModule (
    input clk, areset, bump_left, bump_right, ground, dig,
    output walk_left, walk_right, aaah, digging
);
    localparam LEFT=3'd0, RIGHT=3'd1, FALL_LEFT=3'd2,
               FALL_RIGHT=3'd3, DIG_LEFT=3'd4, DIG_RIGHT=3'd5,
               DEAD=3'd6;
    reg [2:0] state, next_state;
    reg [4:0] fall_cycles;

    always @(*) begin
        next_state = state;
        case (state)
            LEFT: begin
                if (!ground) next_state = FALL_LEFT;
                else if (dig) next_state = DIG_LEFT;
                else if (bump_left) next_state = RIGHT;
            end
            RIGHT: begin
                if (!ground) next_state = FALL_RIGHT;
                else if (dig) next_state = DIG_RIGHT;
                else if (bump_right) next_state = LEFT;
            end
            DIG_LEFT: if (!ground) next_state = FALL_LEFT;
            DIG_RIGHT: if (!ground) next_state = FALL_RIGHT;
            FALL_LEFT: if (ground) begin
                if (fall_cycles > 20) next_state = DEAD;
                else next_state = LEFT;
            end
            FALL_RIGHT: if (ground) begin
                if (fall_cycles > 20) next_state = DEAD;
                else next_state = RIGHT;
            end
            DEAD: next_state = DEAD;
            default: next_state = LEFT;
        endcase
    end

    always @(posedge clk or posedge areset) begin
        if (areset) begin
            state <= LEFT;
            fall_cycles <= 0;
        end else begin
            state <= next_state;
            if (next_state == FALL_LEFT || next_state == FALL_RIGHT) begin
                if (state != FALL_LEFT && state != FALL_RIGHT)
                    fall_cycles <= 1;
                else if (fall_cycles < 21)
                    fall_cycles <= fall_cycles + 1'b1;
            end else fall_cycles <= 0;
        end
    end

    assign walk_left = (state == LEFT);
    assign walk_right = (state == RIGHT);
    assign aaah = (state == FALL_LEFT || state == FALL_RIGHT);
    assign digging = (state == DIG_LEFT || state == DIG_RIGHT);
endmodule
