module TopModule (
    input wire clk,
    input wire in,
    input wire reset,
    output reg [7:0] out_byte,
    output reg done
);
    localparam IDLE = 2'd0, DATA = 2'd1,
               STOP = 2'd2, RECOVER = 2'd3;
    reg [1:0] state;
    reg [2:0] bit_index;
    reg [7:0] data_byte;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            bit_index <= 3'd0;
            data_byte <= 8'd0;
            out_byte <= 8'd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (!in) begin
                        state <= DATA;
                        bit_index <= 3'd0;
                    end
                end
                DATA: begin
                    data_byte[bit_index] <= in;
                    if (bit_index == 3'd7)
                        state <= STOP;
                    else
                        bit_index <= bit_index + 3'd1;
                end
                STOP: begin
                    if (in) begin
                        out_byte <= data_byte;
                        done <= 1'b1;
                        state <= IDLE;
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
