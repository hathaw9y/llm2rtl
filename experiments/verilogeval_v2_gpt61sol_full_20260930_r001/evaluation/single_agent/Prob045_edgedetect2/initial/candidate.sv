module TopModule (
    input  logic       clk,
    input  logic [7:0] in,
    output logic [7:0] anyedge
);
    logic [7:0] previous_in_r;

    always_ff @(posedge clk) begin
        previous_in_r <= in;
        anyedge <= in ^ previous_in_r;
    end
endmodule
