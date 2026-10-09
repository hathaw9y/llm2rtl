module TopModule (
    input  logic clk,
    input  logic aresetn,
    input  logic x,
    output logic z
);
    typedef enum logic [1:0] {
        EMPTY    = 2'b00,
        ONE      = 2'b01,
        ONE_ZERO = 2'b10
    } state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = EMPTY;
        case (state_r)
            EMPTY:    if (x) state_n = ONE;      else state_n = EMPTY;
            ONE:      if (x) state_n = ONE;      else state_n = ONE_ZERO;
            ONE_ZERO: if (x) state_n = ONE;      else state_n = EMPTY;
            default:  state_n = EMPTY;
        endcase
    end

    always_ff @(posedge clk or negedge aresetn) begin
        if (!aresetn)
            state_r <= EMPTY;
        else
            state_r <= state_n;
    end

    assign z = (state_r == ONE_ZERO) && x;
endmodule
