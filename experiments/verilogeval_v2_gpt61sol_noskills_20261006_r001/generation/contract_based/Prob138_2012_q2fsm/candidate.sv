module TopModule (
    input wire clk,
    input wire reset,
    input wire w,
    output wire z
);
    localparam [2:0] A=3'd0, B=3'd1, C=3'd2,
                     D=3'd3, E=3'd4, F=3'd5;
    reg [2:0] state, next_state;

    always @(*) begin
        case (state)
            A: if (w) next_state = B; else next_state = A;
            B: if (w) next_state = C; else next_state = D;
            C: if (w) next_state = E; else next_state = D;
            D: if (w) next_state = F; else next_state = A;
            E: if (w) next_state = E; else next_state = D;
            F: if (w) next_state = C; else next_state = D;
            default: next_state = A;
        endcase
    end

    always @(posedge clk) begin
        if (reset) state <= A;
        else state <= next_state;
    end

    assign z = (state == E) || (state == F);
endmodule
