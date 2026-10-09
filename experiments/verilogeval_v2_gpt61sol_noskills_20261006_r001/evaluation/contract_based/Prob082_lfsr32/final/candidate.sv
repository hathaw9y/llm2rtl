module TopModule (
    input wire clk,
    input wire reset,
    output reg [31:0] q
);
    always @(posedge clk) begin
        if (reset)
            q <= 32'h00000001;
        else
            q <= (q >> 1) ^ ({32{q[0]}} & 32'h80200003);
    end
endmodule
