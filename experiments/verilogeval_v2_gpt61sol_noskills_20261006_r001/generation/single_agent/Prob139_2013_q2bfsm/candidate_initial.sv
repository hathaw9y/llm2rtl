module TopModule (
    input wire clk,
    input wire resetn,
    input wire x,
    input wire y,
    output wire f,
    output wire g
);
    localparam A=4'd0, PULSE=4'd1, SEARCH=4'd2, X1=4'd3,
               X10=4'd4, WAIT_Y1=4'd5, WAIT_Y2=4'd6,
               HOLD_ON=4'd7, HOLD_OFF=4'd8;
    reg [3:0] state, next_state;

    always @(*) begin
        next_state = state;
        case (state)
            A: next_state = PULSE;
            PULSE: next_state = SEARCH;
            SEARCH: begin
                if (x) next_state = X1;
                else next_state = SEARCH;
            end
            X1: begin
                if (x) next_state = X1;
                else next_state = X10;
            end
            X10: begin
                if (x) next_state = WAIT_Y1;
                else next_state = SEARCH;
            end
            WAIT_Y1: begin
                if (y) next_state = HOLD_ON;
                else next_state = WAIT_Y2;
            end
            WAIT_Y2: begin
                if (y) next_state = HOLD_ON;
                else next_state = HOLD_OFF;
            end
            HOLD_ON: next_state = HOLD_ON;
            HOLD_OFF: next_state = HOLD_OFF;
            default: next_state = A;
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) state <= A;
        else state <= next_state;
    end

    assign f = (state == PULSE);
    assign g = (state == WAIT_Y1) || (state == WAIT_Y2) ||
               (state == HOLD_ON);
endmodule
