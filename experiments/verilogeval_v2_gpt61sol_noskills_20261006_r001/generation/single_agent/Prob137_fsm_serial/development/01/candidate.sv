module TopModule (
    input wire clk,
    input wire reset,
    input wire in,
    output wire done
);
    localparam IDLE = 3'd0, DATA = 3'd1, STOP = 3'd2,
               GOOD = 3'd3, WAIT_STOP = 3'd4;
    reg [2:0] state;
    reg [2:0] bit_index;

    assign done = (state == GOOD);

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            bit_index <= 3'd0;
        end else begin
            case (state)
                IDLE, GOOD: begin
                    if (!in) begin
                        state <= DATA;
                        bit_index <= 3'd0;
                    end else begin
                        state <= IDLE;
                    end
                end
                DATA: begin
                    if (bit_index == 3'd7)
                        state <= STOP;
                    else
                        bit_index <= bit_index + 3'd1;
                end
                STOP: begin
                    if (in)
                        state <= GOOD;
                    else
                        state <= WAIT_STOP;
                end
                WAIT_STOP: begin
                    if (in)
                        state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
