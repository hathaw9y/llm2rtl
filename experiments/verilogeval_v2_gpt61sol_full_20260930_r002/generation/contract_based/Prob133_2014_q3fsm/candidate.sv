module TopModule (
    input logic clk,
    input logic reset,
    input logic s,
    input logic w,
    output logic z
);
    typedef enum logic [1:0] {A, B, C, D} state_t;
    state_t state_r;
    logic [1:0] ones_r;

    always_ff @(posedge clk) begin
        if (reset) begin
            state_r <= A;
            ones_r <= 2'd0;
            z <= 1'b0;
        end else begin
            z <= 1'b0;
            case (state_r)
                A: begin
                    ones_r <= 2'd0;
                    if (s) state_r <= B;
                    else state_r <= A;
                end
                B: begin
                    ones_r <= {1'b0, w};
                    state_r <= C;
                end
                C: begin
                    ones_r <= ones_r + {1'b0, w};
                    state_r <= D;
                end
                D: begin
                    z <= ((ones_r + {1'b0, w}) == 2'd2);
                    ones_r <= 2'd0;
                    state_r <= B;
                end
                default: begin
                    state_r <= A;
                    ones_r <= 2'd0;
                end
            endcase
        end
    end
endmodule
