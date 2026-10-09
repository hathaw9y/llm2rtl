module TopModule (
    input wire clk,
    input wire reset,
    input wire data,
    output reg [3:0] count,
    output wire counting,
    output wire done,
    input wire ack
);
    localparam SEARCH = 0, ONE = 1, TWO = 2, THREE = 3,
               LOAD = 4, RUN = 5, FINISHED = 6;
    reg [2:0] state;
    reg [1:0] bit_index;
    reg [9:0] ticks;
    assign counting = (state == RUN);
    assign done = (state == FINISHED);

    always @(posedge clk) begin
        if (reset) begin
            state <= SEARCH;
            count <= 0;
            bit_index <= 0;
            ticks <= 0;
        end else begin
            case (state)
                SEARCH: begin
                    if (data) state <= ONE;
                end
                ONE: begin
                    if (data) state <= TWO;
                    else state <= SEARCH;
                end
                TWO: begin
                    if (!data) state <= THREE;
                end
                THREE: begin
                    if (data) begin
                        state <= LOAD;
                        bit_index <= 0;
                    end else state <= SEARCH;
                end
                LOAD: begin
                    count <= {count[2:0], data};
                    if (bit_index == 3) begin
                        state <= RUN;
                        ticks <= 0;
                    end else bit_index <= bit_index + 1'b1;
                end
                RUN: begin
                    if (ticks == 999) begin
                        ticks <= 0;
                        if (count == 0) state <= FINISHED;
                        else count <= count - 1'b1;
                    end else ticks <= ticks + 1'b1;
                end
                FINISHED: begin
                    if (ack) state <= SEARCH;
                end
                default: state <= SEARCH;
            endcase
        end
    end
endmodule
