module TopModule (
    input wire clk,
    input wire areset,
    input wire x,
    output wire z
);
    localparam [1:0] A = 2'b01, B = 2'b10;
    reg [1:0] state;
    reg [1:0] next_state;

    always @* begin
        case (state)
            A: begin
                if (x) next_state = B;
                else next_state = A;
            end
            B: next_state = B;
            default: next_state = A;
        endcase
    end

    always @(posedge clk or posedge areset) begin
        if (areset) state <= A;
        else state <= next_state;
    end

    assign z = (state == A) ? x : ~x;
endmodule
