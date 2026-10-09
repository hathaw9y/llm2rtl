module TopModule (
    input wire clk,
    input wire load,
    input wire [511:0] data,
    output reg [511:0] q
);
    wire [511:0] left_cells = {1'b0, q[511:1]};
    wire [511:0] right_cells = {q[510:0], 1'b0};

    always @(posedge clk) begin
        if (load)
            q <= data;
        else
            q <= (q | right_cells) & ~(left_cells & q & right_cells);
    end
endmodule
