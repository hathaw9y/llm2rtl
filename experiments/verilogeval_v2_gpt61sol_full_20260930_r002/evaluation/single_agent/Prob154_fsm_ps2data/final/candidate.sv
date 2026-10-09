module TopModule (
    input logic clk,
    input logic reset,
    input logic [7:0] in,
    output logic [23:0] out_bytes,
    output logic done
);
    typedef enum logic [1:0] {SEARCH, SECOND, THIRD, COMPLETE} state_t;
    state_t state_r;
    logic [7:0] first_r, second_r;

    assign done = (state_r == COMPLETE);

    always_ff @(posedge clk) begin
        if (reset) begin
            state_r <= SEARCH;
        end else begin
            case (state_r)
                SEARCH, COMPLETE: begin
                    if (in[3]) begin
                        first_r <= in;
                        state_r <= SECOND;
                    end else begin
                        state_r <= SEARCH;
                    end
                end
                SECOND: begin
                    second_r <= in;
                    state_r <= THIRD;
                end
                THIRD: begin
                    out_bytes <= {first_r, second_r, in};
                    state_r <= COMPLETE;
                end
                default: state_r <= SEARCH;
            endcase
        end
    end
endmodule
