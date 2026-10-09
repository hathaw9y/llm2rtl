module TopModule (
    input  logic         clk,
    input  logic         load,
    input  logic [511:0] data,
    output logic [511:0] q
);
    wire [511:0] left_neighbor = {1'b0, q[511:1]};
    wire [511:0] right_neighbor = {q[510:0], 1'b0};
    wire [511:0] next_cells = (q ^ right_neighbor) |
                                     (~left_neighbor & right_neighbor);

    always_ff @(posedge clk) begin
        if (load)
            q <= data;
        else
            q <= next_cells;
    end
endmodule
