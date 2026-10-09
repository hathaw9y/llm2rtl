module TopModule (
    input logic clk,
    input logic areset,
    input logic x,
    output logic z
);
    typedef enum logic [1:0] { A = 2'b01, B = 2'b10 } state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = state_r;
        case (state_r)
            A: begin
                if (x) state_n = B;
                else state_n = A;
            end
            B: state_n = B;
            default: state_n = A;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset) state_r <= A;
        else state_r <= state_n;
    end

    assign z = x ^ state_r[1];
endmodule
