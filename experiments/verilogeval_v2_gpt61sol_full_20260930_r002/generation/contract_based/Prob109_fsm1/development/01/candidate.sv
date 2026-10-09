module TopModule (
    input  logic clk,
    input  logic areset,
    input  logic in,
    output logic out
);
    logic state_r;

    always_ff @(posedge clk or posedge areset) begin
        if (areset)
            state_r <= 1'b1; // B
        else if (!in)
            state_r <= ~state_r;
    end

    assign out = state_r; // A=0, B=1
endmodule
