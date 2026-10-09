module TopModule (
    input wire clk,
    input wire reset,
    input wire in,
    output reg done
);
    localparam IDLE = 2'd0, DATA = 2'd1, STOP = 2'd2, RECOVER = 2'd3;
    reg [1:0] state;
    reg [2:0] data_index;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            data_index <= 3'd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (!in) begin
                        state <= DATA;
                        data_index <= 3'd0;
                    end
                end
                DATA: begin
                    if (data_index == 3'd7)
                        state <= STOP;
                    else
                        data_index <= data_index + 3'd1;
                end
                STOP: begin
                    if (in) begin
                        state <= IDLE;
                        done <= 1'b1;
                    end else begin
                        state <= RECOVER;
                    end
                end
                RECOVER: begin
                    if (in)
                        state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
