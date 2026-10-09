module TopModule (
    input wire clk,
    input wire [7:0] in,
    output reg [7:0] anyedge
);
    reg [7:0] previous_sample;
    always @(posedge clk) begin
        previous_sample <= in;
        anyedge <= in ^ previous_sample;
    end
endmodule
