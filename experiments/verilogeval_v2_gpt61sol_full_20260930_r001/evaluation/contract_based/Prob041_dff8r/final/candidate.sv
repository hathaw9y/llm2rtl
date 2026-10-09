module TopModule (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] d,
    output logic [7:0] q
);
    always_ff @(posedge clk) begin
        if (reset)
            q <= 8'h00;
        else
            q <= d;
    end
endmodule
