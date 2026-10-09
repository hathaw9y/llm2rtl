module TopModule (
    input logic clk,
    input logic reset,
    input logic in,
    output logic done
);
    typedef enum logic [2:0] {IDLE, DATA, STOP, COMPLETE, RECOVER} state_t;
    state_t state_r, state_n;
    logic [2:0] bit_count_r;

    always_comb begin
        state_n = state_r;
        case (state_r)
            IDLE, COMPLETE: begin
                if (!in) state_n = DATA;
                else state_n = IDLE;
            end
            DATA: begin
                if (bit_count_r == 3'd7) state_n = STOP;
            end
            STOP: begin
                if (in) state_n = COMPLETE;
                else state_n = RECOVER;
            end
            RECOVER: begin
                if (in) state_n = IDLE;
            end
            default: state_n = IDLE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state_r <= IDLE;
            bit_count_r <= 3'd0;
        end else begin
            state_r <= state_n;
            if (state_r == DATA) bit_count_r <= bit_count_r + 3'd1;
            else bit_count_r <= 3'd0;
        end
    end

    assign done = (state_r == COMPLETE);
endmodule
