module TopModule (
    input  logic clk,
    input  logic in,
    output logic out
);
    always_ff @(posedge clk) begin
        out <= out ^ in;
    end
    initial out = '0;
endmodule
