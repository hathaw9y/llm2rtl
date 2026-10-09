module TopModule (
    input wire clk,
    input wire reset,
    input wire s,
    input wire w,
    output wire z
);
    // Boundary states encode the previous group's result. The next
    // sampling edge starts a new group without a gap.
    localparam [2:0] A=3'd0, B0=3'd1, B1=3'd2,
                     C0=3'd3, C1=3'd4,
                     D0=3'd5, D1=3'd6, D2=3'd7;
    reg [2:0] state, next_state;
    always @* begin
        next_state = A;
        case (state)
            A: begin
                if (s) next_state = B0;
                else next_state = A;
            end
            B0, B1: begin
                if (w) next_state = C1;
                else next_state = C0;
            end
            C0: begin
                if (w) next_state = D1;
                else next_state = D0;
            end
            C1: begin
                if (w) next_state = D2;
                else next_state = D1;
            end
            D0: next_state = B0;
            D1: begin
                if (w) next_state = B1;
                else next_state = B0;
            end
            D2: begin
                if (w) next_state = B0;
                else next_state = B1;
            end
            default: next_state = A;
        endcase
    end
    always @(posedge clk) begin
        if (reset) state <= A;
        else state <= next_state;
    end
    assign z = (state == B1);
endmodule
