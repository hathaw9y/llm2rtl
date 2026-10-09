module TopModule (
    input logic clk,
    input logic areset,
    input logic bump_left,
    input logic bump_right,
    output logic walk_left,
    output logic walk_right
);
    typedef enum logic {LEFT = 1'b0, RIGHT = 1'b1} direction_t;
    direction_t state_r, state_n;

    always_comb begin
        state_n = state_r;
        case (state_r)
            LEFT: begin
                if (bump_left) state_n = RIGHT;
                else state_n = LEFT;
            end
            RIGHT: begin
                if (bump_right) state_n = LEFT;
                else state_n = RIGHT;
            end
            default: state_n = LEFT;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset) state_r <= LEFT;
        else state_r <= state_n;
    end

    assign walk_left = (state_r == LEFT);
    assign walk_right = (state_r == RIGHT);
endmodule
