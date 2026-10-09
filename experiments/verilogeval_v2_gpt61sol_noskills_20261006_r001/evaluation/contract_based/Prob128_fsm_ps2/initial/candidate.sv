module TopModule (
    input wire clk,
    input wire reset,
    input wire [7:0] in,
    output wire done
);
    localparam SEARCH = 2'd0, SECOND = 2'd1,
               THIRD = 2'd2, COMPLETE = 2'd3;
    reg [1:0] state, next_state;

    always @* begin
        next_state = SEARCH;
        case (state)
            SEARCH, COMPLETE: begin
                if (in[3]) next_state = SECOND;
                else next_state = SEARCH;
            end
            SECOND: next_state = THIRD;
            THIRD: next_state = COMPLETE;
            default: next_state = SEARCH;
        endcase
    end

    always @(posedge clk) begin
        if (reset) state <= SEARCH;
        else state <= next_state;
    end

    assign done = (state == COMPLETE);
endmodule
