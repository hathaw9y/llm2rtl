module TopModule (
    input wire clk,
    input wire areset,
    input wire bump_left,
    input wire bump_right,
    input wire ground,
    output wire walk_left,
    output wire walk_right,
    output wire aaah
);
    localparam [1:0] LEFT = 2'd0, RIGHT = 2'd1,
                     FALL_LEFT = 2'd2, FALL_RIGHT = 2'd3;
    reg [1:0] state, next_state;

    always @* begin
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

    always @(posedge clk or posedge areset) begin
        if (areset) state <= LEFT;
        else state <= next_state;
    end

    assign walk_left = (state == LEFT);
    assign walk_right = (state == RIGHT);
    assign aaah = (state == FALL_LEFT) || (state == FALL_RIGHT);
endmodule
