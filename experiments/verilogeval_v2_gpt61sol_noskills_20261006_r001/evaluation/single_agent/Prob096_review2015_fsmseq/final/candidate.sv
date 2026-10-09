module TopModule (
    input wire clk,
    input wire reset,
    input wire data,
    output wire start_shifting
);
    localparam [2:0] IDLE = 3'd0, ONE = 3'd1, TWO = 3'd2,
                     THREE = 3'd3, FOUND = 3'd4;
    reg [2:0] state, next_state;

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (data) next_state = ONE;
                else next_state = IDLE;
            end
            ONE: begin
                if (data) next_state = TWO;
                else next_state = IDLE;
            end
            TWO: begin
                if (data) next_state = TWO;
                else next_state = THREE;
            end
            THREE: begin
                if (data) next_state = FOUND;
                else next_state = IDLE;
            end
            FOUND: next_state = FOUND;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (reset) state <= IDLE;
        else state <= next_state;
    end

    assign start_shifting = (state == FOUND);
endmodule
