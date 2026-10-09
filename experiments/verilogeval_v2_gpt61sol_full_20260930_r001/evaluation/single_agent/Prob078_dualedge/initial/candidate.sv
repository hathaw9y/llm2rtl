module TopModule (
    input  logic clk,
    input  logic d,
    output logic q
);
    logic posedge_data_r;
    logic negedge_data_r;

    always_ff @(posedge clk)
        posedge_data_r <= d;

    always_ff @(negedge clk)
        negedge_data_r <= d;

    assign q = clk ? posedge_data_r : negedge_data_r;
endmodule
