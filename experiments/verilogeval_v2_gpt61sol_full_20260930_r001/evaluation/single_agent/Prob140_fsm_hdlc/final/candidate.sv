module TopModule (
    input  logic clk,
    input  logic reset,
    input  logic in,
    output logic disc,
    output logic flag,
    output logic err
);
    typedef enum logic [3:0] {
        ZERO, ONE, TWO, THREE, FOUR, FIVE, SIX, ERROR,
        DISCARD, FLAG
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
            ZERO, DISCARD, FLAG: begin
                if (in) state_n = ONE;
            end
            ONE:   if (in) state_n = TWO;
            TWO:   if (in) state_n = THREE;
            THREE: if (in) state_n = FOUR;
            FOUR:  if (in) state_n = FIVE;
            FIVE:  begin
                if (in) state_n = SIX;
                else    state_n = DISCARD;
            end
            SIX: begin
                if (in) state_n = ERROR;
                else    state_n = FLAG;
            end
            ERROR: if (in) state_n = ERROR;
            default: state_n = ZERO;
        endcase
    end

    assign disc = (state_r == DISCARD);
    assign flag = (state_r == FLAG);
    assign err  = (state_r == ERROR);
endmodule
