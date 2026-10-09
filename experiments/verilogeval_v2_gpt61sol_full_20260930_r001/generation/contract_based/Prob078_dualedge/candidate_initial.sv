module TopModule (
    input  logic clk,
    input  logic d,
    output wire  q
);
    logic rise_sample_r;
    logic fall_sample_r;

    always_ff @(posedge clk)
        rise_sample_r <= d;

    always_ff @(negedge clk)
        fall_sample_r <= d;

    assign q = clk ? rise_sample_r : fall_sample_r;
endmodule
