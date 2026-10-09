module TopModule (
    input  logic clk,
    input  logic areset,
    input  logic x,
    output logic z
);
    typedef enum logic [1:0] {LEADING_ZERO, OUTPUT_ONE, OUTPUT_ZERO} state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = state_r;
        case (state_r)
            LEADING_ZERO: begin
                if (x) state_n = OUTPUT_ONE;
                else   state_n = LEADING_ZERO;
            end
            OUTPUT_ONE, OUTPUT_ZERO: begin
                if (x) state_n = OUTPUT_ZERO;
                else   state_n = OUTPUT_ONE;
            end
            default: state_n = LEADING_ZERO;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset) state_r <= LEADING_ZERO;
        else        state_r <= state_n;
    end

    assign z = (state_r == OUTPUT_ONE);
endmodule
