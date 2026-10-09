module TopModule (
    input wire clk,
    input wire reset,
    output wire shift_ena
);
    reg [2:0] elapsed;

    always @(posedge clk) begin
        if (reset)
            elapsed <= 3'd0;
        else if (elapsed < 3'd4)
            elapsed <= elapsed + 3'd1;
    end

    assign shift_ena = (elapsed < 3'd4);
endmodule
