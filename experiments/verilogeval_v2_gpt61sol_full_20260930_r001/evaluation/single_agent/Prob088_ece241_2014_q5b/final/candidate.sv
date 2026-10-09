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
        z = x;
        case (state_r)
            A: begin
                state_n = x ? B : A;
                z = x;
            end
            B: begin
                state_n = B;
                z = ~x;
            end
            default: begin
                state_n = A;
                z = x;
            end
        endcase
    end

    always_ff @(posedge clk or posedge areset) begin
        if (areset)
            state_r <= A;
        else
            state_r <= state_n;
    end
endmodule
