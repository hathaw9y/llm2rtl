module TopModule (
    input  logic clk,
    input  logic areset,
    input  logic in,
    output logic out
);
    // State encoding: A = 0, B = 1; Moore output equals the state.
    logic state_r;

    always_ff @(posedge clk or posedge areset) begin
        if (areset)
            state_r <= 1'b1;
        else if (!in)
            state_r <= ~state_r;
    end

    assign out = state_r;
endmodule
