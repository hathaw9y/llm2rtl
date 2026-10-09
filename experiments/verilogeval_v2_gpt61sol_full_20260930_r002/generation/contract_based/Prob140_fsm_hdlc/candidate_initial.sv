module TopModule (
    input logic clk,
    input logic reset,
    input logic in,
    output logic disc,
    output logic flag,
    output logic err
);
    typedef enum logic [3:0] {
        ZERO, ONE, TWO, THREE, FOUR, FIVE, SIX, DISCARD, FLAG, ERROR
    } state_t;
    state_t state_r, state_n;

    always_comb begin
        state_n = ZERO;
        case (state_r)
            ZERO, DISCARD, FLAG: begin
                if (in) state_n = ONE;
                else state_n = ZERO;
            end
            ONE: begin
                if (in) state_n = TWO;
                else state_n = ZERO;
            end
            TWO: begin
                if (in) state_n = THREE;
                else state_n = ZERO;
            end
            THREE: begin
                if (in) state_n = FOUR;
                else state_n = ZERO;
            end
            FOUR: begin
                if (in) state_n = FIVE;
                else state_n = ZERO;
            end
            FIVE: begin
                if (in) state_n = SIX;
                else state_n = DISCARD;
            end
            SIX: begin
                if (in) state_n = ERROR;
                else state_n = FLAG;
            end
            ERROR: begin
                if (in) state_n = ERROR;
                else state_n = ZERO;
            end
            default: state_n = ZERO;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) state_r <= ZERO;
        else state_r <= state_n;
    end

    assign disc = (state_r == DISCARD);
    assign flag = (state_r == FLAG);
    assign err = (state_r == ERROR);
endmodule
