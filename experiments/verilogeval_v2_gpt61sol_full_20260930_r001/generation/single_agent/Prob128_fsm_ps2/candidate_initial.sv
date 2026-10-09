module TopModule (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] in,
    output logic       done
);
    typedef enum logic [1:0] {SEARCH, SECOND, THIRD, COMPLETE} state_t;
    state_t state_r;

    always_ff @(posedge clk) begin
        if (reset) begin
            state_r <= SEARCH;
        end else begin
            case (state_r)
                SEARCH:   state_r <= in[3] ? SECOND : SEARCH;
                SECOND:   state_r <= THIRD;
                THIRD:    state_r <= COMPLETE;
                COMPLETE: state_r <= in[3] ? SECOND : SEARCH;
                default:  state_r <= SEARCH;
            endcase
        end
    end

    assign done = (state_r == COMPLETE);
endmodule
