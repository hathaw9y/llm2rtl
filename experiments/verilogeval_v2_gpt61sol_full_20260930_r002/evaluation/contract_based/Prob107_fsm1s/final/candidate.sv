module TopModule (
    input  logic clk,
    input  logic reset,
    input  logic in,
    output logic out
);
    typedef enum logic { A = 1'b0, B = 1'b1 } state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = state_r;
        case (state_r)
            A: begin
                if (in) state_n = A;
                else    state_n = B;
            end
            B: begin
                if (in) state_n = B;
                else    state_n = A;
            end
            default: state_n = state_r;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) state_r <= B;
        else       state_r <= state_n;
    end

    assign out = state_r;
endmodule
