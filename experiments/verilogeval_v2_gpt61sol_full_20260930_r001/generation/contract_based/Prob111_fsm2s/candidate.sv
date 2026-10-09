module TopModule (
    input  logic clk,
    input  logic reset,
    input  logic j,
    input  logic k,
    output logic out
);
    localparam logic OFF = 1'b0;
    localparam logic ON  = 1'b1;
    logic state_r;

    always_ff @(posedge clk) begin
        if (reset)
            state_r <= OFF;
        else if (state_r == OFF)
            state_r <= j ? ON : OFF;
        else
            state_r <= k ? OFF : ON;
    end

    assign out = state_r;
endmodule
