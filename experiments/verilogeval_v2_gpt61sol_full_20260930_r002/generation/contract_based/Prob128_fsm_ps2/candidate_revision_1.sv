module TopModule (
    input logic clk,
    input logic reset,
    input logic [7:0] in,
    output logic done
);
    localparam logic [1:0] SEARCH = 2'd0, SECOND = 2'd1,
                           THIRD = 2'd2, COMPLETE = 2'd3;
    logic [1:0] state_r, state_n;

    always_comb begin
        state_n = SEARCH;
        case (state_r)
            SEARCH, COMPLETE: begin
                if (in[3]) state_n = SECOND;
                else state_n = SEARCH;
            end
            SECOND: state_n = THIRD;
            THIRD: state_n = COMPLETE;
            default: state_n = SEARCH;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) state_r <= SEARCH;
        else state_r <= state_n;
    end

    assign done = (state_r == COMPLETE);
endmodule
