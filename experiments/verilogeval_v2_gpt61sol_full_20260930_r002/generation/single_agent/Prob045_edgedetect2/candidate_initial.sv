module TopModule (
    input  logic       clk,
    input  logic [7:0] in,
    output logic [7:0] anyedge
);
    logic [7:0] previous_r;

    always_ff @(posedge clk) begin
        previous_r <= in;
        anyedge <= in ^ previous_r;
    end
endmodule
