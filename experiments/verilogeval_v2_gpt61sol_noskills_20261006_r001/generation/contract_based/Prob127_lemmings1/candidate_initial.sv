module TopModule (
    input wire clk,
    input wire areset,
    input wire bump_left,
    input wire bump_right,
    output wire walk_left,
    output wire walk_right
);
    reg direction_right;

    always @(posedge clk or posedge areset) begin
        if (areset)
            direction_right <= 1'b0;
        else if (!direction_right) begin
            if (bump_left)
                direction_right <= 1'b1;
        end else begin
            if (bump_right)
                direction_right <= 1'b0;
        end
    end

    assign walk_left = ~direction_right;
    assign walk_right = direction_right;
endmodule
