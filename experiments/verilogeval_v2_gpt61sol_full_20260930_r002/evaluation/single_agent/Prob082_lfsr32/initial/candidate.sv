module TopModule (
    input logic clk,
    input logic reset,
    output logic [31:0] q
);
    always_ff @(posedge clk) begin
        if (reset)
            q <= 32'h00000001;
        else
            q <= {1'b0, q[31:1]} ^ ({32{q[0]}} & 32'h80200003);
    end
endmodule
