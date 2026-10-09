module TopModule (
    input logic clk,
    input logic reset,
    input logic [2:0] s,
    output logic fr2,
    output logic fr1,
    output logic fr0,
    output logic dfr
);
    logic [1:0] level_r, level_n;
    logic supplemental_r;

    always_comb begin
        level_n = level_r;
        case (s)
            3'b000: level_n = 2'd0;
            3'b001: level_n = 2'd1;
            3'b011: level_n = 2'd2;
            3'b111: level_n = 2'd3;
            default: level_n = level_r;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            level_r <= 2'd0;
            supplemental_r <= 1'b1;
        end else begin
            level_r <= level_n;
            if (level_n == 2'd0)
                supplemental_r <= 1'b1;
            else if (level_n == 2'd3)
                supplemental_r <= 1'b0;
            else if (level_n > level_r)
                supplemental_r <= 1'b0;
            else if (level_n < level_r)
                supplemental_r <= 1'b1;
        end
    end

    always_comb begin
        {fr2, fr1, fr0} = 3'bxxx;
        case (level_r)
            2'd0: {fr2, fr1, fr0} = 3'b111;
            2'd1: {fr2, fr1, fr0} = 3'b011;
            2'd2: {fr2, fr1, fr0} = 3'b001;
            2'd3: {fr2, fr1, fr0} = 3'b000;
            default: {fr2, fr1, fr0} = 3'bxxx;
        endcase
        dfr = supplemental_r;
    end
endmodule
