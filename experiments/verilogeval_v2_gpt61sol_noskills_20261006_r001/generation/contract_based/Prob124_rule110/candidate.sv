module TopModule (
    input wire clk,
    input wire load,
    input wire [511:0] data,
    output reg [511:0] q
);
    wire [511:0] left_neighbor = {1'b0, q[511:1]};
    wire [511:0] right_neighbor = {q[510:0], 1'b0};
    wire [511:0] next_q = (q | right_neighbor) &
                                ~(left_neighbor & q & right_neighbor);

    always @(posedge clk) begin
        if (load)
            q <= data;
        else
            q <= next_q;
    end
endmodule
