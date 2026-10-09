module TopModule (
    input logic clk,
    input logic areset,
    input logic x,
    output logic z
);
    typedef enum logic [1:0] {
        BEFORE_ONE, AFTER_ONE_Z1, AFTER_ONE_Z0
    } state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = state_r;
        case (state_r)
            BEFORE_ONE: begin
                if (x) state_n = AFTER_ONE_Z1;
                else state_n = BEFORE_ONE;
            end
            AFTER_ONE_Z1, AFTER_ONE_Z0: begin
                if (x) state_n = AFTER_ONE_Z0;
                else state_n = AFTER_ONE_Z1;
            end
            default: state_n = BEFORE_ONE;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset) state_r <= BEFORE_ONE;
        else state_r <= state_n;
    end

    assign z = (state_r == AFTER_ONE_Z1);
endmodule
