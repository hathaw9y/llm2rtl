module TopModule (
    input  logic clk,
    input  logic aresetn,
    input  logic x,
    output logic z
);
    typedef enum logic [1:0] { IDLE, SEEN_1, SEEN_10 } state_t;
    state_t state_r, state_n;

    always_ff @(posedge clk or negedge aresetn) begin
        if (!aresetn)
            state_r <= IDLE;
        else
            state_r <= state_n;
    end

    always_comb begin
        state_n = IDLE;
        case (state_r)
            IDLE: begin
                if (x) state_n = SEEN_1;
                else   state_n = IDLE;
            end
            SEEN_1: begin
                if (x) state_n = SEEN_1;
                else   state_n = SEEN_10;
            end
            SEEN_10: begin
                if (x) state_n = SEEN_1;
                else   state_n = IDLE;
            end
            default: state_n = IDLE;
        endcase
    end

    assign z = (state_r == SEEN_10) && x;
endmodule
