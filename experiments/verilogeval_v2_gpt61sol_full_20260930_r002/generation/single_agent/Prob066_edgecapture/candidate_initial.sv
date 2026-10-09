module TopModule (
    input logic clk,
    input logic reset,
    input logic [31:0] in,
    output logic [31:0] out
);
    logic [31:0] previous_in_r;

    always_ff @(posedge clk) begin
        previous_in_r <= in;
        if (reset)
            out <= 32'b0;
        else
            out <= out | (previous_in_r & ~in);
    end
endmodule
