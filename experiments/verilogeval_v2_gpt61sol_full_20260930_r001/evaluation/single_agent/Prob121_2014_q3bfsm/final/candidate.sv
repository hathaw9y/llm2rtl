module TopModule (
    input logic clk,
    input logic reset,
    input logic x,
    output logic z
);
    logic [2:0] state_r, state_n;

    always_comb begin
        case (state_r)
            3'b000: state_n = x ? 3'b001 : 3'b000;
            3'b001: state_n = x ? 3'b100 : 3'b001;
            3'b010: state_n = x ? 3'b001 : 3'b010;
            3'b011: state_n = x ? 3'b010 : 3'b001;
            3'b100: state_n = x ? 3'b100 : 3'b011;
            default: state_n = 3'b000;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset)
            state_r <= 3'b000;
        else
            state_r <= state_n;
    end

    assign z = (state_r == 3'b011) || (state_r == 3'b100);
endmodule
