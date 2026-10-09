module TopModule (
    input wire clk,
    input wire areset,
    input wire in,
    output wire out
);
    localparam A = 1'b0, B = 1'b1;
    reg state;

    always @(posedge clk or posedge areset) begin
        if (areset)
            state <= B;
        else begin
            case (state)
                A: begin
                    if (in) state <= A;
                    else    state <= B;
                end
                B: begin
                    if (in) state <= B;
                    else    state <= A;
                end
            endcase
        end
    end

    assign out = state;
endmodule
