module TopModule (
    input wire clk,
    input wire reset,
    input wire data,
    output wire start_shifting
);
    localparam [2:0] EMPTY = 3'd0,
                     ONE = 3'd1,
                     TWO_ONES = 3'd2,
                     ONE_ONE_ZERO = 3'd3,
                     FOUND = 3'd4;
    reg [2:0] state, next_state;

    always @* begin
        next_state = state;
        case (state)
            EMPTY: begin
                if (data) next_state = ONE;
                else next_state = EMPTY;
            end
            ONE: begin
                if (data) next_state = TWO_ONES;
                else next_state = EMPTY;
            end
            TWO_ONES: begin
                if (data) next_state = TWO_ONES;
                else next_state = ONE_ONE_ZERO;
            end
            ONE_ONE_ZERO: begin
                if (data) next_state = FOUND;
                else next_state = EMPTY;
            end
            FOUND: next_state = FOUND;
            default: next_state = EMPTY;
        endcase
    end

    always @(posedge clk) begin
        if (reset) state <= EMPTY;
        else state <= next_state;
    end

    assign start_shifting = (state == FOUND);
endmodule
