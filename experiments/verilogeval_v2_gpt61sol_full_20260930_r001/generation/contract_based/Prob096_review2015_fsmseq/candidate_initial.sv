module TopModule (
    input  logic clk,
    input  logic reset,
    input  logic data,
    output logic start_shifting
);
    typedef enum logic [2:0] {
        SEARCH = 3'd0,
        PREFIX_1 = 3'd1,
        PREFIX_11 = 3'd2,
        PREFIX_110 = 3'd3,
        FOUND = 3'd4
    } state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = state_r;
        case (state_r)
            SEARCH:     if (data) state_n = PREFIX_1;
            PREFIX_1:   if (data) state_n = PREFIX_11;
                        else state_n = SEARCH;
            PREFIX_11:  if (!data) state_n = PREFIX_110;
            PREFIX_110: if (data) state_n = FOUND;
                        else state_n = SEARCH;
            FOUND:      state_n = FOUND;
            default:    state_n = SEARCH;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset)
            state_r <= SEARCH;
        else
            state_r <= state_n;
    end

    assign start_shifting = (state_r == FOUND);
endmodule
