module TopModule (
    input wire clk,
    input wire reset,
    input wire data,
    output reg [3:0] count,
    output wire counting,
    output wire done,
    input wire ack
);
    localparam SEARCH0=0, SEARCH1=1, SEARCH11=2, SEARCH110=3,
               CAPTURE=4, RUN=5, WAIT_ACK=6;
    reg [2:0] state;
    reg [1:0] bits_received;
    reg [9:0] ticks;
    assign counting = (state == RUN);
    assign done = (state == WAIT_ACK);

    always @(posedge clk) begin
        if (reset) begin
            state <= SEARCH0;
            count <= 0;
            bits_received <= 0;
            ticks <= 0;
        end else begin
            case (state)
                SEARCH0: begin
                    if (data) state <= SEARCH1;
                    else state <= SEARCH0;
                end
                SEARCH1: begin
                    if (data) state <= SEARCH11;
                    else state <= SEARCH0;
                end
                SEARCH11: begin
                    if (data) state <= SEARCH11;
                    else state <= SEARCH110;
                end
                SEARCH110: begin
                    if (data) begin
                        state <= CAPTURE;
                        bits_received <= 0;
                    end else state <= SEARCH0;
                end
                CAPTURE: begin
                    count <= {count[2:0], data};
                    bits_received <= bits_received + 1'b1;
                    if (bits_received == 3) begin
                        state <= RUN;
                        ticks <= 0;
                    end
                end
                RUN: begin
                    if (ticks == 999) begin
                        ticks <= 0;
                        if (count == 0) state <= WAIT_ACK;
                        else count <= count - 1'b1;
                    end else ticks <= ticks + 1'b1;
                end
                WAIT_ACK: begin
                    if (ack) state <= SEARCH0;
                end
                default: state <= SEARCH0;
            endcase
        end
    end
endmodule
