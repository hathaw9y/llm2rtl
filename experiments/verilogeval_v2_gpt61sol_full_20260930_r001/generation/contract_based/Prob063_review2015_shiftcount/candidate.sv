module TopModule (
    input  logic       clk,
    input  logic       shift_ena,
    input  logic       count_ena,
    input  logic       data,
    output logic [3:0] q
);
    always_ff @(posedge clk) begin
        if (shift_ena)
            q <= {q[2:0], data};
        else if (count_ena)
            q <= q - 4'd1;
    end
endmodule
