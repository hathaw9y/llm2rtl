module TopModule (
    input wire clk,
    input wire reset,
    input wire [7:0] in,
    output reg [23:0] out_bytes,
    output reg done
);
    localparam SEARCH = 2'd0, SECOND = 2'd1, THIRD = 2'd2;
    reg [1:0] state;
    reg [23:0] packet;
    reg pending;

    always @(posedge clk) begin
        if (reset) begin
            state <= SEARCH;
            pending <= 1'b0;
            done <= 1'b0;
        end else begin
            done <= pending;
            pending <= 1'b0;
            if (pending)
                out_bytes <= packet;
            case (state)
                SEARCH: begin
                    if (in[3]) begin
                        packet[23:16] <= in;
                        state <= SECOND;
                    end else begin
                        state <= SEARCH;
                    end
                end
                SECOND: begin
                    packet[15:8] <= in;
                    state <= THIRD;
                end
                THIRD: begin
                    packet[7:0] <= in;
                    pending <= 1'b1;
                    state <= SEARCH;
                end
                default: state <= SEARCH;
            endcase
        end
    end
endmodule
