module TopModule (
    input  logic       clk,
    input  logic       resetn,
    input  logic [2:0] r,
    output logic [2:0] g
);
    localparam logic [1:0] A = 2'd0, B = 2'd1,
                           C = 2'd2, D = 2'd3;
    logic [1:0] state_r, state_n;

    always_comb begin
        state_n = A;
        case (state_r)
            A: begin
                if (r[0])      state_n = B;
                else if (r[1]) state_n = C;
                else if (r[2]) state_n = D;
            end
            B: if (r[0]) state_n = B;
            C: if (r[1]) state_n = C;
            D: if (r[2]) state_n = D;
            default: state_n = A;
        endcase
    end

    always_ff @(posedge clk) begin
        if (!resetn) state_r <= A;
        else         state_r <= state_n;
    end

    always_comb begin
        g = 3'b000;
        case (state_r)
            B: g = 3'b001;
            C: g = 3'b010;
            D: g = 3'b100;
            default: g = 3'b000;
        endcase
    end
endmodule
