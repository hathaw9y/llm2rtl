module TopModule (
    input logic clk,
    input logic a,
    output logic [2:0] q
);
    always_ff @(posedge clk) begin
        if (a)
            q <= 3'd4;
        else if (q == 3'd6)
            q <= 3'd0;
        else
            q <= q + 3'd1;
    end
endmodule
