module TopModule (
    input wire clk,
    input wire reset,
    output wire [2:0] ena,
    output reg [15:0] q
);
    assign ena[0] = (q[3:0] == 4'd9);
    assign ena[1] = (q[7:0] == 8'h99);
    assign ena[2] = (q[11:0] == 12'h999);

    always @(posedge clk) begin
        if (reset)
            q <= 16'h0000;
        else begin
            if (q[3:0] == 4'd9) q[3:0] <= 4'd0;
            else q[3:0] <= q[3:0] + 4'd1;
            if (ena[0]) begin
                if (q[7:4] == 4'd9) q[7:4] <= 4'd0;
                else q[7:4] <= q[7:4] + 4'd1;
            end
            if (ena[1]) begin
                if (q[11:8] == 4'd9) q[11:8] <= 4'd0;
                else q[11:8] <= q[11:8] + 4'd1;
            end
            if (ena[2]) begin
                if (q[15:12] == 4'd9) q[15:12] <= 4'd0;
                else q[15:12] <= q[15:12] + 4'd1;
            end
        end
    end
endmodule
