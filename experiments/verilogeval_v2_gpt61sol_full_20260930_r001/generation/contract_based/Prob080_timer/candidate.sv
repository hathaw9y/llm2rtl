module TopModule (
    input  logic       clk,
    input  logic       load,
    input  logic [9:0] data,
    output logic       tc
);
    logic [9:0] count_r;

    always_ff @(posedge clk) begin
        if (load)
            count_r <= data;
        else if (count_r != 10'd0)
            count_r <= count_r - 10'd1;
    end

    assign tc = (count_r == 10'd0);
endmodule
