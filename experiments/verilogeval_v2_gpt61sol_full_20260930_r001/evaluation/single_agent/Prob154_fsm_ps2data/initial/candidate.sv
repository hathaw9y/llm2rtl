module TopModule (
    input  logic        clk,
    input  logic        reset,
    input  logic [7:0]  in,
    output logic [23:0] out_bytes,
    output logic        done
);
    typedef enum logic [1:0] {SEARCH, SECOND, THIRD, REPORT} state_t;
    state_t state_r;
    logic [23:0] packet_r;

    always_ff @(posedge clk) begin
        if (reset) begin
            state_r   <= SEARCH;
            packet_r  <= 24'b0;
            out_bytes <= 24'b0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state_r)
                SEARCH: begin
                    if (in[3]) begin
                        packet_r[23:16] <= in;
                        state_r <= SECOND;
                    end
                end
                SECOND: begin
                    packet_r[15:8] <= in;
                    state_r <= THIRD;
                end
                THIRD: begin
                    packet_r[7:0] <= in;
                    state_r <= REPORT;
                end
                REPORT: begin
                    out_bytes <= packet_r;
                    done <= 1'b1;
                    if (in[3]) begin
                        packet_r[23:16] <= in;
                        state_r <= SECOND;
                    end else begin
                        state_r <= SEARCH;
                    end
                end
                default: state_r <= SEARCH;
            endcase
        end
    end
endmodule
