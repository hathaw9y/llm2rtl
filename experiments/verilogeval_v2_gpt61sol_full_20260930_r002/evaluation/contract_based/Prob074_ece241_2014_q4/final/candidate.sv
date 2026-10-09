module TopModule (
    input  logic clk,
    input  logic x,
    output wire z
);
    // The specification assumes all three flip-flops start at zero.
    logic q_xor_r = 1'b0;
    logic q_and_r = 1'b0;
    logic q_or_r  = 1'b0;

    always_ff @(posedge clk) begin
        q_xor_r <= x ^ q_xor_r;
        q_and_r <= x & ~q_and_r;
        q_or_r  <= x | ~q_or_r;
    end

    assign z = ~(q_xor_r | q_and_r | q_or_r);
endmodule
