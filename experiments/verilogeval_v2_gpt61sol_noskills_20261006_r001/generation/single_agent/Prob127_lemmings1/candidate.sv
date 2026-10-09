module TopModule (
    input wire clk,
    input wire areset,
    input wire bump_left,
    input wire bump_right,
    output wire walk_left,
    output wire walk_right
);
    localparam LEFT = 1'b0, RIGHT = 1'b1;
    reg state;
    reg next_state;

    always @(*) begin
        if (state == LEFT) begin
            if (bump_left) next_state = RIGHT;
            else next_state = LEFT;
        end else begin
            if (bump_right) next_state = LEFT;
            else next_state = RIGHT;
        end
    end

    always @(posedge clk or posedge areset) begin
        if (areset) state <= LEFT;
        else state <= next_state;
    end

    assign walk_left = (state == LEFT);
    assign walk_right = (state == RIGHT);
endmodule
