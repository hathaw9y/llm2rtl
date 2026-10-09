module TopModule (
    input  logic clk,
    input  logic areset,
    input  logic j,
    input  logic k,
    output logic out
);
    localparam logic OFF = 1'b0;
    localparam logic ON  = 1'b1;
    logic state_r;

    always_ff @(posedge clk or posedge areset) begin
        if (areset)
            state_r <= OFF;
        else begin
            case (state_r)
                OFF: state_r <= j ? ON : OFF;
                ON:  state_r <= k ? OFF : ON;
                default: state_r <= OFF;
            endcase
        end
    end

    assign out = state_r;
endmodule
