module TopModule (
    input logic clk,
    input logic a,
    input logic b,
    output wire q,
    output logic state
);
    always_ff @(posedge clk) begin
        state <= (a & b) | (state & (a | b));
    end
    assign q = a ^ b ^ state;
endmodule
