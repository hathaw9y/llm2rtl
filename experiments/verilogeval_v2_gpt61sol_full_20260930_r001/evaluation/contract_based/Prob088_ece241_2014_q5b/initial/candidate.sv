module TopModule (
    input  logic clk,
    input  logic areset,
    input  logic x,
    output logic z
);
    localparam logic [1:0] A = 2'b01;
    localparam logic [1:0] B = 2'b10;
    logic [1:0] state_r, state_n;

    always_comb begin
        state_n = A;
        case (state_r)
            A: state_n = x ? B : A;
            B: state_n = B;
            default: state_n = A;
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset)
            state_r <= A;
        else
            state_r <= state_n;
    end

    assign z = state_r[0] ? x : ~x;
endmodule
