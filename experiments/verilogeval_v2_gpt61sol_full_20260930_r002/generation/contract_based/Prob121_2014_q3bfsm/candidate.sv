module TopModule (
    input logic clk,
    input logic reset,
    input logic x,
    output logic z
);
    logic [2:0] state_r, state_n;

    always_comb begin
        state_n = 3'b000;
        case (state_r)
            3'b000: begin
                if (x) state_n = 3'b001;
                else state_n = 3'b000;
            end
            3'b001: begin
                if (x) state_n = 3'b100;
                else state_n = 3'b001;
            end
            3'b010: begin
                if (x) state_n = 3'b001;
                else state_n = 3'b010;
            end
            3'b011: begin
                if (x) state_n = 3'b010;
                else state_n = 3'b001;
            end
            3'b100: begin
                if (x) state_n = 3'b100;
                else state_n = 3'b011;
            end
            default: state_n = 3'b000;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) state_r <= 3'b000;
        else state_r <= state_n;
    end

    assign z = (state_r == 3'b011) || (state_r == 3'b100);
endmodule
