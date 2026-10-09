module TopModule (
    input  logic clk,
    input  logic areset,
    input  logic x,
    output logic z
);
    typedef enum logic [1:0] {
        BEFORE_ONE = 2'b00,
        OUTPUT_ONE = 2'b01,
        OUTPUT_ZERO = 2'b10
    } state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = BEFORE_ONE;
        case (state_r)
            BEFORE_ONE: state_n = x ? OUTPUT_ONE : BEFORE_ONE;
            OUTPUT_ONE, OUTPUT_ZERO:
                state_n = x ? OUTPUT_ZERO : OUTPUT_ONE;
            default: state_n = BEFORE_ONE;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset)
            state_r <= BEFORE_ONE;
        else
            state_r <= state_n;
    end

    assign z = (state_r == OUTPUT_ONE);
endmodule
