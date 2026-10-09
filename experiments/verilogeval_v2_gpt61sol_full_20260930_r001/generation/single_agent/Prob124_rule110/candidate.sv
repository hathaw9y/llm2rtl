module TopModule (
    input  logic         clk,
    input  logic         load,
    input  logic [511:0] data,
    output logic [511:0] q
);
    logic [511:0] left_w;
    logic [511:0] right_w;
    logic [511:0] next_w;

    assign left_w  = {1'b0, q[511:1]};
    assign right_w = {q[510:0], 1'b0};
    assign next_w  = (q | right_w) & ~(left_w & q & right_w);

    always_ff @(posedge clk) begin
        if (load)
            q <= data;
        else
            q <= next_w;
    end
endmodule
