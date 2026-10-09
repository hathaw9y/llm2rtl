module TopModule (
    input  logic clk,
    input  logic resetn,
    input  logic in,
    output logic out
);
    logic [3:0] shift_r;

    always_ff @(posedge clk) begin
        if (!resetn)
            shift_r <= 4'b0000;
        else
            shift_r <= {shift_r[2:0], in};
    end

    assign out = shift_r[3];
endmodule
