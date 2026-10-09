module TopModule (
    input wire clk,
    input wire enable,
    input wire S,
    input wire A,
    input wire B,
    input wire C,
    output wire Z
);
    reg [7:0] Q;
    always @(posedge clk) begin
        if (enable)
            Q <= {Q[6:0], S};
    end
    assign Z = Q[{A, B, C}];
endmodule
