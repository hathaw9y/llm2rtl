module TopModule (
    input  logic clk,
    input  logic reset,
    input  logic in,
    output logic disc,
    output logic flag,
    output logic err
);
    typedef enum logic [3:0] {
        ZERO, ONE, TWO, THREE, FOUR, FIVE, SIX, ERROR, DISCARD, FLAG
    } state_t;
    state_t state_r, state_n;

    always_ff @(posedge clk) begin
        if (reset)
            state_r <= ZERO;
        else
            state_r <= state_n;
    end

    always_comb begin
        state_n = ZERO;
        case (state_r)
            ZERO, DISCARD, FLAG: state_n = in ? ONE : ZERO;
            ONE:   state_n = in ? TWO : ZERO;
            TWO:   state_n = in ? THREE : ZERO;
            THREE: state_n = in ? FOUR : ZERO;
            FOUR:  state_n = in ? FIVE : ZERO;
            FIVE:  state_n = in ? SIX : DISCARD;
            SIX:   state_n = in ? ERROR : FLAG;
            ERROR: state_n = in ? ERROR : ZERO;
            default: state_n = ZERO;
        endcase
    end

    always_comb begin
        disc = (state_r == DISCARD);
        flag = (state_r == FLAG);
        err  = (state_r == ERROR);
    end
endmodule
