module TopModule (
    input clk, areset, bump_left, bump_right, ground, dig,
    output walk_left, walk_right, aaah, digging
);
    typedef enum logic [2:0] {WL, WR, DL, DR, FL, FR, DEAD} state_t;
    state_t state, next_state;
    logic [4:0] fall_cycles;

    always_comb begin
        next_state = state;
        case (state)
            WL: begin
                if (!ground) next_state = FL;
                else if (dig) next_state = DL;
                else if (bump_left) next_state = WR;
            end
            WR: begin
                if (!ground) next_state = FR;
                else if (dig) next_state = DR;
                else if (bump_right) next_state = WL;
            end
            DL: if (!ground) next_state = FL;
            DR: if (!ground) next_state = FR;
            FL: if (ground) begin
                if (fall_cycles > 5'd20) next_state = DEAD;
                else next_state = WL;
            end
            FR: if (ground) begin
                if (fall_cycles > 5'd20) next_state = DEAD;
                else next_state = WR;
            end
            DEAD: next_state = DEAD;
            default: next_state = WL;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset) begin
            state <= WL;
            fall_cycles <= 5'd0;
        end else begin
            state <= next_state;
            if (state == FL || state == FR) begin
                if (!ground && fall_cycles < 5'd21)
                    fall_cycles <= fall_cycles + 5'd1;
            end else if (next_state == FL || next_state == FR)
                fall_cycles <= 5'd1;
            else
                fall_cycles <= 5'd0;
        end
    end

    assign walk_left = (state == WL);
    assign walk_right = (state == WR);
    assign aaah = (state == FL || state == FR);
    assign digging = (state == DL || state == DR);
endmodule
