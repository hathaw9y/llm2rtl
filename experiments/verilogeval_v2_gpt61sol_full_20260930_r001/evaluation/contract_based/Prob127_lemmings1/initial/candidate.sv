module TopModule (
    input  logic clk,
    input  logic areset,
    input  logic bump_left,
    input  logic bump_right,
    output logic walk_left,
    output logic walk_right
);
    localparam logic LEFT = 1'b0;
    localparam logic RIGHT = 1'b1;
    logic state_r;

    always_ff @(posedge clk or posedge areset) begin
        if (areset)
            state_r <= LEFT;
        else if (state_r == LEFT)
            state_r <= bump_left ? RIGHT : LEFT;
        else
            state_r <= bump_right ? LEFT : RIGHT;
    end

    assign walk_left = (state_r == LEFT);
    assign walk_right = (state_r == RIGHT);
endmodule
