module TopModule (
    input logic clk,
    input logic enable,
    input logic S,
    input logic A,
    input logic B,
    input logic C,
    output logic Z
);
    logic [7:0] Q;

    always_ff @(posedge clk) begin
        if (enable)
            Q <= {Q[6:0], S};
    end

    assign Z = Q[{A, B, C}];
endmodule
