module TopModule (
    input  logic clk,
    input  logic reset,
    input  logic data,
    input  logic done_counting,
    input  logic ack,
    output logic shift_ena,
    output logic counting,
    output logic done
);
    typedef enum logic [3:0] {
        SEARCH, PREFIX_1, PREFIX_11, PREFIX_110,
        SHIFT_1, SHIFT_2, SHIFT_3, SHIFT_4, COUNT, NOTIFY
    } state_t;
    state_t state_r, state_n;

    always_ff @(posedge clk) begin
        if (reset)
            state_r <= SEARCH;
        else
            state_r <= state_n;
    end

    always_comb begin
        state_n = state_r;
        shift_ena = 1'b0;
        counting = 1'b0;
        done = 1'b0;
        case (state_r)
            SEARCH:     if (data) state_n = PREFIX_1;
            PREFIX_1:   if (data) state_n = PREFIX_11;
                        else state_n = SEARCH;
            PREFIX_11:  if (!data) state_n = PREFIX_110;
            PREFIX_110: if (data) state_n = SHIFT_1;
                        else state_n = SEARCH;
            SHIFT_1: begin shift_ena = 1'b1; state_n = SHIFT_2; end
            SHIFT_2: begin shift_ena = 1'b1; state_n = SHIFT_3; end
            SHIFT_3: begin shift_ena = 1'b1; state_n = SHIFT_4; end
            SHIFT_4: begin shift_ena = 1'b1; state_n = COUNT; end
            COUNT: begin
                counting = 1'b1;
                if (done_counting) state_n = NOTIFY;
            end
            NOTIFY: begin
                done = 1'b1;
                if (ack) state_n = SEARCH;
            end
            default: state_n = SEARCH;
        endcase
    end
endmodule
