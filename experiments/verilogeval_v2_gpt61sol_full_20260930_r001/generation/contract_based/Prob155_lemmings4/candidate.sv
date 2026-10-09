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
    typedef enum logic [1:0] {WALK, FALL, DIGGING, SPLAT} activity_t;
    activity_t activity_r;
    logic direction_r; // 0: left, 1: right
    logic [4:0] fall_count_r;

    always_ff @(posedge clk or posedge areset) begin
        if (areset) begin
            activity_r <= WALK;
            direction_r <= 1'b0;
            fall_count_r <= 5'd0;
        end else begin
            case (activity_r)
                WALK: begin
                    fall_count_r <= 5'd0;
                    if (!ground) begin
                        activity_r <= FALL;
                        fall_count_r <= 5'd1;
                    end else if (dig) begin
                        activity_r <= DIGGING;
                    end else if ((!direction_r && bump_left) ||
                                 (direction_r && bump_right)) begin
                        direction_r <= ~direction_r;
                    end
                end
                DIGGING: begin
                    if (!ground) begin
                        activity_r <= FALL;
                        fall_count_r <= 5'd1;
                    end
                end
                FALL: begin
                    if (ground) begin
                        if (fall_count_r > 5'd20)
                            activity_r <= SPLAT;
                        else
                            activity_r <= WALK;
                        fall_count_r <= 5'd0;
                    end else if (fall_count_r < 5'd21) begin
                        fall_count_r <= fall_count_r + 5'd1;
                    end
                end
                SPLAT: begin
                    activity_r <= SPLAT;
                end
                default: begin
                    activity_r <= WALK;
                    direction_r <= 1'b0;
                    fall_count_r <= 5'd0;
                end
            endcase
        end
    end

    assign walk_left  = (activity_r == WALK) && !direction_r;
    assign walk_right = (activity_r == WALK) && direction_r;
    assign aaah       = (activity_r == FALL);
    assign digging    = (activity_r == DIGGING);
endmodule
