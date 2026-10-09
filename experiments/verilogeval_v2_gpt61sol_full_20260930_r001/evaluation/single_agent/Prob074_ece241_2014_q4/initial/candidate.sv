module TopModule (
    input  logic clk,
    input  logic x,
    output wire  z
);
    logic xor_r = 1'b0;
    logic and_r = 1'b0;
    logic or_r  = 1'b0;

    always_ff @(posedge clk) begin
        xor_r <= x ^ xor_r;
        and_r <= x & ~and_r;
        or_r  <= x | ~or_r;
    end

    assign z = ~(xor_r | and_r | or_r);
endmodule
