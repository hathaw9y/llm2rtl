module TopModule (
    input wire clk,
    input wire reset,
    input wire j,
    input wire k,
    output wire out
);
    localparam OFF = 1'b0, ON = 1'b1;
    reg state;
    reg next_state;

    always @(*) begin
        case (state)
            OFF: begin
                if (j) next_state = ON;
                else next_state = OFF;
            end
            ON: begin
                if (k) next_state = OFF;
                else next_state = ON;
            end
            default: next_state = OFF;
        endcase
    end

    always @(posedge clk) begin
        if (reset) state <= OFF;
        else state <= next_state;
    end

    assign out = state;
endmodule
