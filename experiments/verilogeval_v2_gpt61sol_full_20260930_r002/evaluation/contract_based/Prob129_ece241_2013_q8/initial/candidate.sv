module TopModule (
    input logic clk,
    input logic aresetn,
    input logic x,
    output logic z
);
    typedef enum logic [1:0] {EMPTY, ONE, ONE_ZERO} state_t;
    state_t state_r, state_n;

    always_ff @(posedge clk or negedge aresetn) begin
        if (!aresetn)
            state_r <= EMPTY;
        else
            state_r <= state_n;
    end

    always_comb begin
        state_n = EMPTY;
        case (state_r)
            EMPTY: begin
                if (x) state_n = ONE;
                else state_n = EMPTY;
            end
            ONE: begin
                if (x) state_n = ONE;
                else state_n = ONE_ZERO;
            end
            ONE_ZERO: begin
                if (x) state_n = ONE;
                else state_n = EMPTY;
            end
            default: state_n = EMPTY;
        endcase
    end

    assign z = (state_r == ONE_ZERO) && x;
endmodule
