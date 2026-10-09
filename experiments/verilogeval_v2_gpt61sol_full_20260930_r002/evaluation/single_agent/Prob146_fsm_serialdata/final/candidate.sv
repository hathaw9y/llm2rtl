module TopModule (
    input  logic       clk,
    input  logic       in,
    input  logic       reset,
    output logic [7:0] out_byte,
    output logic       done
);
    typedef enum logic [1:0] {IDLE, DATA, STOP, RECOVER} state_t;
    state_t state_r;
    logic [2:0] bit_index_r;
    logic [7:0] byte_r;

    always_ff @(posedge clk) begin
        if (reset) begin
            state_r <= IDLE;
            bit_index_r <= 3'd0;
            byte_r <= 8'd0;
            out_byte <= 8'd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state_r)
                IDLE: begin
                    if (!in) begin
                        state_r <= DATA;
                        bit_index_r <= 3'd0;
                    end
                end
                DATA: begin
                    byte_r[bit_index_r] <= in;
                    if (bit_index_r == 3'd7)
                        state_r <= STOP;
                    else
                        bit_index_r <= bit_index_r + 3'd1;
                end
                STOP: begin
                    if (in) begin
                        out_byte <= byte_r;
                        done <= 1'b1;
                        state_r <= IDLE;
                    end else begin
                        state_r <= RECOVER;
                    end
                end
                RECOVER: begin
                    if (in)
                        state_r <= IDLE;
                end
                default: state_r <= IDLE;
            endcase
        end
    end
endmodule
