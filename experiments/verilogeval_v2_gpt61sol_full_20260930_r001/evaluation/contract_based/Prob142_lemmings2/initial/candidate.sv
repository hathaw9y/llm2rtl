module TopModule (
    input  logic clk,
    input  logic areset,
    input  logic bump_left,
    input  logic bump_right,
    input  logic ground,
    output logic walk_left,
    output logic walk_right,
    output logic aaah
);
    typedef enum logic [1:0] {
        WALK_LEFT = 2'b00,
        WALK_RIGHT = 2'b01,
        FALL_LEFT = 2'b10,
        FALL_RIGHT = 2'b11
    } state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = state_r;
        case (state_r)
            WALK_LEFT: begin
                if (!ground) state_n = FALL_LEFT;
                else if (bump_left) state_n = WALK_RIGHT;
            end
            WALK_RIGHT: begin
                if (!ground) state_n = FALL_RIGHT;
                else if (bump_right) state_n = WALK_LEFT;
            end
            FALL_LEFT: begin
                if (ground) state_n = WALK_LEFT;
            end
            FALL_RIGHT: begin
                if (ground) state_n = WALK_RIGHT;
            end
            default: state_n = WALK_LEFT;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset) state_r <= WALK_LEFT;
        else state_r <= state_n;
    end

    assign walk_left = (state_r == WALK_LEFT);
    assign walk_right = (state_r == WALK_RIGHT);
    assign aaah = (state_r == FALL_LEFT) || (state_r == FALL_RIGHT);
endmodule
