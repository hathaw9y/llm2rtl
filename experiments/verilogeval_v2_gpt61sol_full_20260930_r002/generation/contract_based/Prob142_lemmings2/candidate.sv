module TopModule (
    input logic clk,
    input logic areset,
    input logic bump_left,
    input logic bump_right,
    input logic ground,
    output logic walk_left,
    output logic walk_right,
    output logic aaah
);
    typedef enum logic [1:0] {LEFT, RIGHT, FALL_LEFT, FALL_RIGHT} state_t;
    state_t state_r, state_n;

    always_ff @(posedge clk or posedge areset) begin
        if (areset) state_r <= LEFT;
        else state_r <= state_n;
    end

    always_comb begin
        state_n = state_r;
        case (state_r)
            LEFT: begin
                if (!ground) state_n = FALL_LEFT;
                else if (bump_left) state_n = RIGHT;
            end
            RIGHT: begin
                if (!ground) state_n = FALL_RIGHT;
                else if (bump_right) state_n = LEFT;
            end
            FALL_LEFT: begin
                if (ground) state_n = LEFT;
            end
            FALL_RIGHT: begin
                if (ground) state_n = RIGHT;
            end
            default: state_n = LEFT;
        endcase
    end

    assign walk_left = (state_r == LEFT);
    assign walk_right = (state_r == RIGHT);
    assign aaah = (state_r == FALL_LEFT) || (state_r == FALL_RIGHT);
endmodule
