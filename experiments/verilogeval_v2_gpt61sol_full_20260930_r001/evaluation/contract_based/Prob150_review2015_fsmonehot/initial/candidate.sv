module TopModule (
    input  logic       d,
    input  logic       done_counting,
    input  logic       ack,
    input  logic [9:0] state,
    output logic       B3_next,
    output logic       S_next,
    output logic       S1_next,
    output logic       Count_next,
    output logic       Wait_next,
    output logic       done,
    output logic       counting,
    output logic       shift_ena
);
    // One-hot state bits: S, S1, S11, S110, B0, B1, B2, B3, Count, Wait.
    assign B3_next    = state[6];
    assign S_next     = ((state[0] | state[1] | state[3]) & ~d)
                      | (state[9] & ack);
    assign S1_next    = state[0] & d;
    assign Count_next = state[7] | (state[8] & ~done_counting);
    assign Wait_next  = (state[8] & done_counting) | (state[9] & ~ack);

    assign done      = state[9];
    assign counting  = state[8];
    assign shift_ena = |state[7:4];
endmodule
