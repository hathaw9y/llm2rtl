module TopModule (
    input logic clk,
    input logic reset,
    input logic s,
    input logic w,
    output logic z
);
    typedef enum logic [1:0] {A, FIRST, SECOND, THIRD} phase_t;
    phase_t phase_r;
    logic [1:0] ones_r;

    always_ff @(posedge clk) begin
        if (reset) begin
            phase_r <= A;
            ones_r <= 2'd0;
            z <= 1'b0;
        end else begin
            z <= 1'b0;
            case (phase_r)
                A: begin
                    ones_r <= 2'd0;
                    if (s) phase_r <= FIRST;
                end
                FIRST: begin
                    ones_r <= {1'b0, w};
                    phase_r <= SECOND;
                end
                SECOND: begin
                    ones_r <= ones_r + {1'b0, w};
                    phase_r <= THIRD;
                end
                THIRD: begin
                    z <= ((ones_r + {1'b0, w}) == 2'd2);
                    ones_r <= 2'd0;
                    phase_r <= FIRST;
                end
                default: begin
                    phase_r <= A;
                    ones_r <= 2'd0;
                end
            endcase
        end
    end
endmodule
