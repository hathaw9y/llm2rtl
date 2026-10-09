module TopModule (
    input logic clk,
    input logic reset,
    input logic data,
    output logic [3:0] count,
    output logic counting,
    output logic done,
    input logic ack
);
    typedef enum logic [3:0] {SEARCH, ONE, TWO, THREE,
                              BIT3, BIT2, BIT1, BIT0, RUN, WAIT_ACK} state_t;
    state_t state_r;
    logic [9:0] ticks_r;

    assign counting = (state_r == RUN);
    assign done = (state_r == WAIT_ACK);

    always_ff @(posedge clk) begin
        if (reset) begin
            state_r <= SEARCH;
            count <= 4'd0;
            ticks_r <= 10'd0;
        end else begin
            case (state_r)
                SEARCH: begin
                    if (data) state_r <= ONE;
                    else state_r <= SEARCH;
                end
                ONE: begin
                    if (data) state_r <= TWO;
                    else state_r <= SEARCH;
                end
                TWO: begin
                    if (data) state_r <= TWO;
                    else state_r <= THREE;
                end
                THREE: begin
                    if (data) state_r <= BIT3;
                    else state_r <= SEARCH;
                end
                BIT3: begin
                    count <= {count[2:0], data};
                    state_r <= BIT2;
                end
                BIT2: begin
                    count <= {count[2:0], data};
                    state_r <= BIT1;
                end
                BIT1: begin
                    count <= {count[2:0], data};
                    state_r <= BIT0;
                end
                BIT0: begin
                    count <= {count[2:0], data};
                    ticks_r <= 10'd0;
                    state_r <= RUN;
                end
                RUN: begin
                    if (ticks_r == 10'd999) begin
                        ticks_r <= 10'd0;
                        if (count == 4'd0) state_r <= WAIT_ACK;
                        else count <= count - 4'd1;
                    end else ticks_r <= ticks_r + 10'd1;
                end
                WAIT_ACK: begin
                    if (ack) state_r <= SEARCH;
                end
                default: begin
                    state_r <= SEARCH;
                    ticks_r <= 10'd0;
                    count <= 4'd0;
                end
            endcase
        end
    end
endmodule
