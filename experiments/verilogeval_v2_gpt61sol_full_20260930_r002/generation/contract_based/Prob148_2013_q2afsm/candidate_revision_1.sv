module TopModule (
    input logic clk,
    input logic resetn,
    input logic [2:0] r,
    output logic [2:0] g
);
    localparam logic [1:0] A = 2'b00, B = 2'b01,
                           C = 2'b10, D = 2'b11;
    logic [1:0] state_r, state_n;

    always_comb begin
        state_n = A;
        case (state_r)
            A: begin
                if (r[0]) state_n = B;
                else if (r[1]) state_n = C;
                else if (r[2]) state_n = D;
                else state_n = A;
            end
            B: begin
                if (r[0]) state_n = B;
                else state_n = A;
            end
            C: begin
                if (r[1]) state_n = C;
                else state_n = A;
            end
            D: begin
                if (r[2]) state_n = D;
                else state_n = A;
            end
            default: state_n = A;
        endcase
    end

    always_ff @(posedge clk) begin
        if (!resetn) state_r <= A;
        else state_r <= state_n;
    end

    assign g[0] = (state_r == B);
    assign g[1] = (state_r == C);
    assign g[2] = (state_r == D);
endmodule
