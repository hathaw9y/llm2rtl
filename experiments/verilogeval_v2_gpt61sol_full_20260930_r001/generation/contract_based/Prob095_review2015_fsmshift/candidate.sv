module TopModule (
    input  logic clk,
    input  logic reset,
    output logic shift_ena
);
    logic [2:0] elapsed_cycles_r;

    always_ff @(posedge clk) begin
        if (reset)
            elapsed_cycles_r <= 3'd0;
        else if (elapsed_cycles_r < 3'd4)
            elapsed_cycles_r <= elapsed_cycles_r + 3'd1;
    end

    assign shift_ena = (elapsed_cycles_r < 3'd4);
endmodule
