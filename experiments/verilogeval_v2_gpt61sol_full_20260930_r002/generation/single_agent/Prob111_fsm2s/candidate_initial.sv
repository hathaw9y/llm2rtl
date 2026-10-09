module TopModule (
    input  logic clk,
    input  logic reset,
    input  logic j,
    input  logic k,
    output logic out
);
    typedef enum logic {OFF = 1'b0, ON = 1'b1} state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = state_r;
        case (state_r)
            OFF: begin
                if (j) state_n = ON;
                else   state_n = OFF;
            end
            ON: begin
                if (k) state_n = OFF;
                else   state_n = ON;
            end
            default: state_n = OFF;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) state_r <= OFF;
        else       state_r <= state_n;
    end

    assign out = (state_r == ON);
endmodule
