module TopModule (
    input wire clk,
    input wire areset,
    input wire x,
    output wire z
);
    localparam [1:0] BEFORE_ONE = 2'd0,
                     OUTPUT_ONE = 2'd1,
                     OUTPUT_ZERO = 2'd2;
    reg [1:0] state;
    reg [1:0] next_state;

    always @(*) begin
        case (state)
            BEFORE_ONE: begin
                if (x) next_state = OUTPUT_ONE;
                else next_state = BEFORE_ONE;
            end
            OUTPUT_ONE, OUTPUT_ZERO: begin
                if (x) next_state = OUTPUT_ZERO;
                else next_state = OUTPUT_ONE;
            end
            default: next_state = BEFORE_ONE;
        endcase
    end

    always @(posedge clk or posedge areset) begin
        if (areset) state <= BEFORE_ONE;
        else state <= next_state;
    end

    assign z = (state == OUTPUT_ONE);
endmodule
