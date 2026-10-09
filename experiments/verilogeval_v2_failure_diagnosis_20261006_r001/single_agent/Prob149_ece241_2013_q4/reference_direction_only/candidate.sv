module TopModule (
    input logic clk,
    input logic reset,
    input logic [2:0] s,
    output logic fr2,
    output logic fr1,
    output logic fr0,
    output logic dfr
);
    logic [1:0] level_r;
    logic supplemental_r;
    logic [1:0] level_w;

    always_comb begin
        level_w = level_r;
        case (s)
            3'b000: level_w = 2'd0;
            3'b001: level_w = 2'd1;
            3'b011: level_w = 2'd2;
            3'b111: level_w = 2'd3;
            default: level_w = level_r;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            level_r <= 2'd0;
            supplemental_r <= 1'b1;
        end else begin
            level_r <= level_w;
            if (level_w == 2'd0)
                supplemental_r <= 1'b1;
            else if (level_w == 2'd3)
                supplemental_r <= 1'b0;
            else if (level_w != level_r)
                supplemental_r <= (level_w < level_r);
        end
    end

    assign fr0 = (level_r != 2'd3);
    assign fr1 = (level_r < 2'd2);
    assign fr2 = (level_r == 2'd0);
    assign dfr = supplemental_r;
endmodule
