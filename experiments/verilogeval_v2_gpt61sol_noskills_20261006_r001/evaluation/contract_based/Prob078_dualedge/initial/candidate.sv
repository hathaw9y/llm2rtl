module TopModule (
    input  wire clk,
    input  wire d,
    output wire q
);
    reg rising_sample;
    reg falling_sample;

    always @(posedge clk)
        rising_sample <= d;

    always @(negedge clk)
        falling_sample <= d;

    assign q = clk ? rising_sample : falling_sample;
endmodule
