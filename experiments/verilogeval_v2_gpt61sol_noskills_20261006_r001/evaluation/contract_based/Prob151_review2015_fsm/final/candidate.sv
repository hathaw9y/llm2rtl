module TopModule (
    input wire clk,
    input wire reset,
    input wire data,
    input wire done_counting,
    input wire ack,
    output wire shift_ena,
    output wire counting,
    output wire done
);
    typedef enum logic [3:0] {
        SEARCH, PREFIX_1, PREFIX_11, PREFIX_110,
        SHIFT_1, SHIFT_2, SHIFT_3, SHIFT_4, COUNT, NOTIFY
    } state_t;
    state_t state, next_state;

    always_comb begin
        next_state = state;
        case (state)
            SEARCH: begin
                if (data) next_state = PREFIX_1;
                else next_state = SEARCH;
            end
            PREFIX_1: begin
                if (data) next_state = PREFIX_11;
                else next_state = SEARCH;
            end
            PREFIX_11: begin
                if (data) next_state = PREFIX_11;
                else next_state = PREFIX_110;
            end
            PREFIX_110: begin
                if (data) next_state = SHIFT_1;
                else next_state = SEARCH;
            end
            SHIFT_1: next_state = SHIFT_2;
            SHIFT_2: next_state = SHIFT_3;
            SHIFT_3: next_state = SHIFT_4;
            SHIFT_4: next_state = COUNT;
            COUNT: begin
                if (done_counting) next_state = NOTIFY;
                else next_state = COUNT;
            end
            NOTIFY: begin
                if (ack) next_state = SEARCH;
                else next_state = NOTIFY;
            end
            default: next_state = SEARCH;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) state <= SEARCH;
        else state <= next_state;
    end

    assign shift_ena = (state == SHIFT_1) || (state == SHIFT_2) ||
                       (state == SHIFT_3) || (state == SHIFT_4);
    assign counting = (state == COUNT);
    assign done = (state == NOTIFY);
endmodule
