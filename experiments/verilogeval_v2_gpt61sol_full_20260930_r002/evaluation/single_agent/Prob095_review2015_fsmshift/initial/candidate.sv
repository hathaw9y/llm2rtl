module TopModule (
    input  logic clk,
    input  logic reset,
    output logic shift_ena
);
    logic [2:0] count_r;

    always_ff @(posedge clk) begin
        if (reset)
            count_r <= 3'd0;
        else if (count_r < 3'd4)
            count_r <= count_r + 3'd1;
    end

    assign shift_ena = (count_r < 3'd4);
endmodule
