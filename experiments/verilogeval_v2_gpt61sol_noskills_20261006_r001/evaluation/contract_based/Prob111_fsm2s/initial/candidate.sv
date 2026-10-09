module TopModule (
    input wire clk,
    input wire reset,
    input wire j,
    input wire k,
    output wire out
);
    localparam OFF = 1'b0, ON = 1'b1;
    reg state;

    always @(posedge clk) begin
        if (reset)
            state <= OFF;
        else if (state == OFF) begin
            if (j)
                state <= ON;
            else
                state <= OFF;
        end else begin
            if (k)
                state <= OFF;
            else
                state <= ON;
        end
    end

    assign out = state;
endmodule
