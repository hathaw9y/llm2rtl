module TopModule (
    input logic clk,
    input logic reset,
    input logic j,
    input logic k,
    output logic out
);
    typedef enum logic {OFF = 1'b0, ON = 1'b1} state_t;
    state_t state_r;

    always_ff @(posedge clk) begin
        if (reset)
            state_r <= OFF;
        else begin
            case (state_r)
                OFF: state_r <= j ? ON : OFF;
                ON:  state_r <= k ? OFF : ON;
                default: state_r <= OFF;
            endcase
        end
    end

    assign out = (state_r == ON);
endmodule
