module TopModule (
    input logic clk,
    input logic aresetn,
    input logic x,
    output logic z
);
    typedef enum logic [1:0] {EMPTY = 2'd0, PREFIX_1 = 2'd1, PREFIX_10 = 2'd2} state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = EMPTY;
        case (state_r)
            EMPTY: if (x) state_n = PREFIX_1;
            PREFIX_1: if (x) state_n = PREFIX_1; else state_n = PREFIX_10;
            PREFIX_10: if (x) state_n = PREFIX_1;
            default: state_n = EMPTY;
        endcase
    end

    always_ff @(posedge clk or negedge aresetn) begin
        if (!aresetn) state_r <= EMPTY;
        else state_r <= state_n;
    end

    assign z = (state_r == PREFIX_10) && x;
endmodule
