module TopModule (
    input logic clk,
    input logic reset,
    input logic data,
    input logic done_counting,
    input logic ack,
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
        if (reset) state_r <= SEARCH;
        else state_r <= state_n;
    end

    always_comb begin
        state_n = state_r;
        case (state_r)
            SEARCH: begin
                if (data) state_n = PREFIX_1;
                else state_n = SEARCH;
            end
            PREFIX_1: begin
                if (data) state_n = PREFIX_11;
                else state_n = SEARCH;
            end
            PREFIX_11: begin
                if (data) state_n = PREFIX_11;
                else state_n = PREFIX_110;
            end
            PREFIX_110: begin
                if (data) state_n = SHIFT_1;
                else state_n = SEARCH;
            end
            SHIFT_1: state_n = SHIFT_2;
            SHIFT_2: state_n = SHIFT_3;
            SHIFT_3: state_n = SHIFT_4;
            SHIFT_4: state_n = COUNT;
            COUNT: begin
                if (done_counting) state_n = NOTIFY;
            end
            NOTIFY: begin
                if (ack) state_n = SEARCH;
            end
            default: state_n = SEARCH;
        endcase
    end

    assign shift_ena = (state_r == SHIFT_1) || (state_r == SHIFT_2)
                    || (state_r == SHIFT_3) || (state_r == SHIFT_4);
    assign counting = (state_r == COUNT);
    assign done = (state_r == NOTIFY);
endmodule
