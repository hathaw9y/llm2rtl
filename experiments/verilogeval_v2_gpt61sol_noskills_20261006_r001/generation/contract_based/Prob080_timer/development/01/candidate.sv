module TopModule (
    input wire clk,
    input wire load,
    input wire [9:0] data,
    output wire tc
);
    reg [9:0] count;

    always @(posedge clk) begin
        if (load)
            count <= data;
        else if (count != 10'd0)
            count <= count - 10'd1;
    end

    assign tc = (count == 10'd0);
endmodule
