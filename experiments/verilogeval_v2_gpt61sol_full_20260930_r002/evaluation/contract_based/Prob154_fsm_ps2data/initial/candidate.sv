module TopModule (
    input logic clk,
    input logic reset,
    input logic [7:0] in,
    output logic [23:0] out_bytes,
    output logic done
);
    typedef enum logic [1:0] {SEARCH, SECOND, THIRD} state_t;
    state_t state_r;
    logic [7:0] first_r, second_r;

    always_ff @(posedge clk) begin
        if (reset) begin
            state_r <= SEARCH;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state_r)
                SEARCH: begin
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
                    done <= 1'b1;
                    state_r <= SEARCH;
                end
                default: state_r <= SEARCH;
            endcase
        end
    end
endmodule
