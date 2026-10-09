module TopModule (
    input wire clk,
    input wire reset,
    input wire [2:0] s,
    output reg fr2,
    output reg fr1,
    output reg fr0,
    output reg dfr
);
    reg [1:0] level;

    always @(posedge clk) begin
        if (reset) begin
            level <= 2'd0;
            dfr <= 1'b1;
        end else begin
            case (s)
                3'b000: begin
                    level <= 2'd0;
                    dfr <= 1'b1;
                end
                3'b001: begin
                    level <= 2'd1;
                    if (level < 2'd1)
                        dfr <= 1'b1;
                    else if (level > 2'd1)
                        dfr <= 1'b0;
                end
                3'b011: begin
                    level <= 2'd2;
                    if (level < 2'd2)
                        dfr <= 1'b1;
                    else if (level > 2'd2)
                        dfr <= 1'b0;
                end
                3'b111: begin
                    level <= 2'd3;
                    dfr <= 1'b0;
                end
                default: begin end
            endcase
        end
    end

    always @* begin
        case (level)
            2'd0: {fr2, fr1, fr0} = 3'b111;
            2'd1: {fr2, fr1, fr0} = 3'b011;
            2'd2: {fr2, fr1, fr0} = 3'b001;
            2'd3: {fr2, fr1, fr0} = 3'b000;
            default: {fr2, fr1, fr0} = 3'bxxx;
        endcase
    end
endmodule
