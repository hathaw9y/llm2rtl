module TopModule (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] in,
    output logic       done
);
    typedef enum logic [1:0] {
        SEARCH, BYTE_TWO, BYTE_THREE, COMPLETE
    } state_t;
    state_t state_r;

    always_ff @(posedge clk) begin
        if (reset) begin
            state_r <= SEARCH;
        end else begin
            case (state_r)
                SEARCH, COMPLETE: begin
                    if (in[3]) state_r <= BYTE_TWO;
                    else       state_r <= SEARCH;
                end
                BYTE_TWO:   state_r <= BYTE_THREE;
                BYTE_THREE: state_r <= COMPLETE;
                default:    state_r <= SEARCH;
            endcase
        end
    end

    assign done = (state_r == COMPLETE);
endmodule
