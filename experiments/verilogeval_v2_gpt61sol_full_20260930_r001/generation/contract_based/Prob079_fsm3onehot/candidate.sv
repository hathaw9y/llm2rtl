module TopModule (
    input  logic       in,
    input  logic [3:0] state,
    output logic [3:0] next_state,
    output logic       out
);
    assign next_state[0] = ~in & (state[0] | state[2]);
    assign next_state[1] =  in & (state[0] | state[1] | state[3]);
    assign next_state[2] = ~in & (state[1] | state[3]);
    assign next_state[3] =  in & state[2];
    assign out = state[3];
endmodule
