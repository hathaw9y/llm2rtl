module TopModule (
    input  logic clk,
    input  logic reset,
    input  logic w,
    output logic z
);
    localparam logic [2:0] A = 3'd0, B = 3'd1, C = 3'd2,
                           D = 3'd3, E = 3'd4, F = 3'd5;
    logic [2:0] state_r, state_n;

    always_comb begin
        state_n = A;
        case (state_r)
            A: state_n = w ? A : B;
            B: state_n = w ? D : C;
            C: state_n = w ? D : E;
            D: state_n = w ? A : F;
            E: state_n = w ? D : E;
            F: state_n = w ? D : C;
            default: state_n = A;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset)
            state_r <= A;
        else
            state_r <= state_n;
    end

    assign z = (state_r == E) || (state_r == F);
endmodule
