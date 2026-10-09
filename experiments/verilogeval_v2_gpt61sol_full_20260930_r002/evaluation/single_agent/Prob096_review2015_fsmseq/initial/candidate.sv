module TopModule (
    input logic clk,
    input logic reset,
    input logic data,
    output logic start_shifting
);
    typedef enum logic [2:0] { IDLE, SEEN_1, SEEN_11, SEEN_110, FOUND } state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = state_r;
        case (state_r)
            IDLE: begin
                if (data) state_n = SEEN_1;
                else state_n = IDLE;
            end
            SEEN_1: begin
                if (data) state_n = SEEN_11;
                else state_n = IDLE;
            end
            SEEN_11: begin
                if (data) state_n = SEEN_11;
                else state_n = SEEN_110;
            end
            SEEN_110: begin
                if (data) state_n = FOUND;
                else state_n = IDLE;
            end
            FOUND: state_n = FOUND;
            default: state_n = IDLE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) state_r <= IDLE;
        else state_r <= state_n;
    end

    assign start_shifting = (state_r == FOUND);
endmodule
