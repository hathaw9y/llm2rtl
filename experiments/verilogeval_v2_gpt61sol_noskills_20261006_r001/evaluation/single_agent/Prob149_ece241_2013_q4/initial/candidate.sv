module TopModule (
    input wire clk,
    input wire reset,
    input wire [2:0] s,
    output wire fr2,
    output wire fr1,
    output wire fr0,
    output wire dfr
);
    reg [1:0] level;
    reg rising;
    reg [1:0] sensed_level;

    always @* begin
        case (s)
            3'b000: sensed_level = 2'd0;
            3'b001: sensed_level = 2'd1;
            3'b011: sensed_level = 2'd2;
            3'b111: sensed_level = 2'd3;
            default: sensed_level = level;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            level <= 2'd0;
            rising <= 1'b1;
        end else begin
            level <= sensed_level;
            if (sensed_level != level)
                rising <= (sensed_level > level);
        end
    end

    assign fr2 = (level == 2'd0);
    assign fr1 = (level < 2'd2);
    assign fr0 = (level < 2'd3);
    assign dfr = (level == 2'd0) | ((level != 2'd3) & rising);
endmodule
