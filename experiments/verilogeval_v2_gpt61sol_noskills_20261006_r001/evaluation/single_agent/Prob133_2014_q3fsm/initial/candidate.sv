module TopModule (
    input wire clk,
    input wire reset,
    input wire s,
    input wire w,
    output wire z
);
    // B0/B1 begin a group; B1 also reports the preceding group's result.
    localparam [2:0] A=3'd0, B0=3'd1, B1=3'd2,
                     C0=3'd3, C1=3'd4,
                     D0=3'd5, D1=3'd6, D2=3'd7;
    reg [2:0] state, next_state;
    always @* begin
        next_state = A;
        case (state)
            A:  if (s) next_state = B0; else next_state = A;
            B0, B1: if (w) next_state = C1; else next_state = C0;
            C0: if (w) next_state = D1; else next_state = D0;
            C1: if (w) next_state = D2; else next_state = D1;
            D0: next_state = B0;
            D1: if (w) next_state = B1; else next_state = B0;
            D2: if (w) next_state = B0; else next_state = B1;
            default: next_state = A;
        endcase
    end
    always @(posedge clk) begin
        if (reset) state <= A;
        else state <= next_state;
    end
    assign z = (state == B1);
endmodule
