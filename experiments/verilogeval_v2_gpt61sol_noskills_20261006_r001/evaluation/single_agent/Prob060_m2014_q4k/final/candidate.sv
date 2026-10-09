module TopModule (
    input wire clk,
    input wire resetn,
    input wire in,
    output wire out
);
    reg [3:0] stages;
    always @(posedge clk) begin
        if (!resetn)
            stages <= 4'b0000;
        else
            stages <= {stages[2:0], in};
    end
    assign out = stages[3];
endmodule
