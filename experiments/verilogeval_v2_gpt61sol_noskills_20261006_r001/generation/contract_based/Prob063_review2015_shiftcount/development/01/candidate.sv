module TopModule (
    input wire clk,
    input wire shift_ena,
    input wire count_ena,
    input wire data,
    output reg [3:0] q
);
    always @(posedge clk) begin
        if (shift_ena)
            q <= {q[2:0], data};
        else if (count_ena)
            q <= q - 4'd1;
    end
endmodule
