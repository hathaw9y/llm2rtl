module TopModule (
    input wire clk,
    input wire reset,
    output wire shift_ena
);
    reg [2:0] remaining;

    always @(posedge clk) begin
        if (reset)
            remaining <= 3'd4;
        else if (remaining != 3'd0)
            remaining <= remaining - 3'd1;
    end

    assign shift_ena = (remaining != 3'd0);
endmodule
