module TopModule (
    input  logic clk,
    input  logic d,
    output wire  q
);
    logic posedge_r;
    logic negedge_r;

    always_ff @(posedge clk)
        posedge_r <= d;

    always_ff @(negedge clk)
        negedge_r <= d;

    assign q = clk ? posedge_r : negedge_r;
endmodule
