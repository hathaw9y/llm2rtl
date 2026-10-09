module TopModule (
    input  logic clk,
    input  logic d,
    output logic q
);
    logic rising_sample_r;
    logic falling_sample_r;

    always_ff @(posedge clk)
        rising_sample_r <= d;

    always_ff @(negedge clk)
        falling_sample_r <= d;

    assign q = clk ? rising_sample_r : falling_sample_r;
endmodule
