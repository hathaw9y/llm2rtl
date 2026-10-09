module TopModule (
    input  logic clk,
    input  logic a,
    output logic q
);
    logic a_sample_r;

    always_ff @(posedge clk) begin
        a_sample_r <= a;
        q <= ~a_sample_r;
    end
endmodule
