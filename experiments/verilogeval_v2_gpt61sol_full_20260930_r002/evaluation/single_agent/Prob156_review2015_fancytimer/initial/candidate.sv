module TopModule (
    input logic clk,
    input logic reset,
    input logic data,
    output logic [3:0] count,
    output logic counting,
    output logic done,
    input logic ack
);
    typedef enum logic [2:0] {SEARCH, ONE, TWO, THREE, LOAD, RUN, WAIT_ACK} state_t;
    state_t state_r;
    logic [1:0] bit_r;
    logic [9:0] cycle_r;

    assign counting = (state_r == RUN);
    assign done = (state_r == WAIT_ACK);

    always_ff @(posedge clk) begin
        if (reset) begin
            state_r <= SEARCH;
            count <= 4'd0;
            bit_r <= 2'd0;
            cycle_r <= 10'd0;
        end else begin
            case (state_r)
                SEARCH: begin
                    if (data) state_r <= ONE;
                end
                ONE: begin
                    if (data) state_r <= TWO;
                    else state_r <= SEARCH;
                end
                TWO: begin
                    if (!data) state_r <= THREE;
                end
                THREE: begin
                    if (data) begin
                        state_r <= LOAD;
                        bit_r <= 2'd0;
                    end else state_r <= SEARCH;
                end
                LOAD: begin
                    count <= {count[2:0], data};
                    if (bit_r == 2'd3) begin
                        state_r <= RUN;
                        cycle_r <= 10'd0;
                    end else bit_r <= bit_r + 2'd1;
                end
                RUN: begin
                    if (cycle_r == 10'd999) begin
                        cycle_r <= 10'd0;
                        if (count == 4'd0) state_r <= WAIT_ACK;
                        else count <= count - 4'd1;
                    end else cycle_r <= cycle_r + 10'd1;
                end
                WAIT_ACK: begin
                    if (ack) state_r <= SEARCH;
                end
                default: state_r <= SEARCH;
            endcase
        end
    end
endmodule
