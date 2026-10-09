module TopModule (
    input  logic clk,
    input  logic reset,
    input  logic in,
    output logic out
);
    localparam logic A = 1'b0;
    localparam logic B = 1'b1;
    logic state_r;

    always_ff @(posedge clk) begin
        if (reset)
            state_r <= B;
        else if (!in)
            state_r <= ~state_r;
    end

    assign out = (state_r == B);
endmodule
