module TopModule (
    input logic clk,
    input logic reset,
    input logic data,
    output logic [3:0] count,
    output logic counting,
    output logic done,
    input logic ack
);
    typedef enum logic [2:0] {SEARCH_0, SEARCH_1, SEARCH_11,
                              SEARCH_110, CAPTURE, RUN, WAIT_ACK} state_t;
    state_t state_r;
    logic [1:0] capture_index_r;
    logic [3:0] remaining_r;
    logic [9:0] elapsed_r;

    assign count = remaining_r;
    assign counting = (state_r == RUN);
    assign done = (state_r == WAIT_ACK);

    always_ff @(posedge clk) begin
        if (reset) begin
            state_r <= SEARCH_0;
            capture_index_r <= 2'd0;
            remaining_r <= 4'd0;
            elapsed_r <= 10'd0;
        end else begin
            case (state_r)
                SEARCH_0: state_r <= data ? SEARCH_1 : SEARCH_0;
                SEARCH_1: state_r <= data ? SEARCH_11 : SEARCH_0;
                SEARCH_11: state_r <= data ? SEARCH_11 : SEARCH_110;
                SEARCH_110: begin
                    if (data) begin
                        state_r <= CAPTURE;
                        capture_index_r <= 2'd0;
                    end else state_r <= SEARCH_0;
                end
                CAPTURE: begin
                    remaining_r <= {remaining_r[2:0], data};
                    if (capture_index_r == 2'd3) begin
                        state_r <= RUN;
                        elapsed_r <= 10'd0;
                    end else capture_index_r <= capture_index_r + 2'd1;
                end
                RUN: begin
                    if (elapsed_r == 10'd999) begin
                        elapsed_r <= 10'd0;
                        if (remaining_r == 4'd0) state_r <= WAIT_ACK;
                        else remaining_r <= remaining_r - 4'd1;
                    end else elapsed_r <= elapsed_r + 10'd1;
                end
                WAIT_ACK: if (ack) state_r <= SEARCH_0;
                default: begin
                    state_r <= SEARCH_0;
                    capture_index_r <= 2'd0;
                    remaining_r <= 4'd0;
                    elapsed_r <= 10'd0;
                end
            endcase
        end
    end
endmodule
