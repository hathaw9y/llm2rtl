module TopModule (
    input logic clk,
    input logic reset,
    input logic in,
    output logic done
);
    typedef enum logic [1:0] {IDLE, DATA, STOP, RECOVER} state_t;
    state_t state_r;
    logic [2:0] data_index_r;

    always_ff @(posedge clk) begin
        if (reset) begin
            state_r <= IDLE;
            data_index_r <= 3'd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state_r)
                IDLE: begin
                    if (!in) begin
                        state_r <= DATA;
                        data_index_r <= 3'd0;
                    end
                end
                DATA: begin
                    if (data_index_r == 3'd7)
                        state_r <= STOP;
                    else
                        data_index_r <= data_index_r + 3'd1;
                end
                STOP: begin
                    if (in) begin
                        state_r <= IDLE;
                        done <= 1'b1;
                    end else begin
                        state_r <= RECOVER;
                    end
                end
                RECOVER: begin
                    if (in)
                        state_r <= IDLE;
                end
                default: begin
                    state_r <= IDLE;
                    data_index_r <= 3'd0;
                end
            endcase
        end
    end
endmodule
