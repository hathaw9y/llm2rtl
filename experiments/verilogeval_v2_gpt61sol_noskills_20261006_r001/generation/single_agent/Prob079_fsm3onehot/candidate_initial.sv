module TopModule (
    input wire in,
    input wire [3:0] state,
    output wire [3:0] next_state,
    output wire out
);
    assign next_state[0] = (state[0] | state[2]) & ~in;
    assign next_state[1] = (state[0] | state[1] | state[3]) & in;
    assign next_state[2] = (state[1] | state[3]) & ~in;
    assign next_state[3] = state[2] & in;
    assign out = state[3];
endmodule
