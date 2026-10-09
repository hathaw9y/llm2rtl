module TopModule (
    input wire clk,
    input wire aresetn,
    input wire x,
    output wire z
);
    localparam [1:0] EMPTY = 2'd0, ONE = 2'd1, ONE_ZERO = 2'd2;
    reg [1:0] state;
    reg [1:0] next_state;

    always @* begin
        case (state)
            EMPTY: begin
                if (x) next_state = ONE;
                else next_state = EMPTY;
            end
            ONE: begin
                if (x) next_state = ONE;
                else next_state = ONE_ZERO;
            end
            ONE_ZERO: begin
                if (x) next_state = ONE;
                else next_state = EMPTY;
            end
            default: next_state = EMPTY;
        endcase
    end

    always @(posedge clk or negedge aresetn) begin
        if (!aresetn) state <= EMPTY;
        else state <= next_state;
    end

    assign z = (state == ONE_ZERO) && x;
endmodule
