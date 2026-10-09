module TopModule (
    input wire clk,
    input wire reset,
    input wire [31:0] in,
    output reg [31:0] out
);
    reg [31:0] previous_in;

    always @(posedge clk) begin
        previous_in <= in;
        if (reset)
            out <= 32'b0;
        else
            out <= out | (previous_in & ~in);
    end
endmodule
