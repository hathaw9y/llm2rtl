module TopModule (
    input wire clk,
    input wire reset,
    input wire in,
    output wire disc,
    output wire flag,
    output wire err
);
    localparam [3:0] ZERO = 4'd0, ONE = 4'd1, TWO = 4'd2,
                     THREE = 4'd3, FOUR = 4'd4, FIVE = 4'd5,
                     SIX = 4'd6, ERROR = 4'd7, DISCARD = 4'd8,
                     FLAG = 4'd9;
    reg [3:0] state, next_state;

    always @(*) begin
        next_state = ZERO;
        case (state)
            ZERO, DISCARD, FLAG: begin
                if (in) next_state = ONE;
                else next_state = ZERO;
            end
            ONE: begin
                if (in) next_state = TWO;
                else next_state = ZERO;
            end
            TWO: begin
                if (in) next_state = THREE;
                else next_state = ZERO;
            end
            THREE: begin
                if (in) next_state = FOUR;
                else next_state = ZERO;
            end
            FOUR: begin
                if (in) next_state = FIVE;
                else next_state = ZERO;
            end
            FIVE: begin
                if (in) next_state = SIX;
                else next_state = DISCARD;
            end
            SIX: begin
                if (in) next_state = ERROR;
                else next_state = FLAG;
            end
            ERROR: begin
                if (in) next_state = ERROR;
                else next_state = ZERO;
            end
            default: next_state = ZERO;
        endcase
    end

    always @(posedge clk) begin
        if (reset) state <= ZERO;
        else state <= next_state;
    end

    assign disc = (state == DISCARD);
    assign flag = (state == FLAG);
    assign err = (state == ERROR);
endmodule
